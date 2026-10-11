// SPDX-License-Identifier: GPL-2.0-only
// Independent loopback launcher; upstream Canary and OTClient gameplay is untouched.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web.Script.Serialization;
using System.Windows.Forms;

public class LocalSettings {
    public string Email, Password;
    public int DatabasePort, GamePort, LoginPort;
}
class StockLauncher : Form {
    readonly string root = AppDomain.CurrentDomain.BaseDirectory.TrimEnd('\\');
    readonly Label status = new Label();
    readonly Button stop = new Button();
    readonly object logGate = new object();
    readonly ManualResetEvent startupFinished = new ManualResetEvent(false);
    readonly bool serverOnly;
    readonly LocalSettings settings;
    Process database, server, client;
    TcpListener login;
    FileStream instanceLock;
    volatile bool stopping;
    bool done;
    string ServerDir { get { return Path.Combine(root,"server"); } }
    string Bin { get { return Path.Combine(root,"database-runtime","bin"); } }
    [STAThread] static void Main(string[] args) {
        Application.EnableVisualStyles(); Application.SetCompatibleTextRenderingDefault(false);
        try { Application.Run(new StockLauncher(Array.IndexOf(args,"--server-only")>=0)); }
        catch(Exception) { MessageBox.Show("Setup is missing or invalid. Run scripts/Prepare.ps1 first. Your existing saves were not changed.","Tibia Solo Stock"); }
    }
    StockLauncher(bool only) {
        serverOnly=only;
        settings=new JavaScriptSerializer().Deserialize<LocalSettings>(File.ReadAllText(Path.Combine(root,"settings.json")));
        if(settings==null || String.IsNullOrEmpty(settings.Email) || String.IsNullOrEmpty(settings.Password)) throw new Exception("Missing settings");
        foreach(int port in new[]{settings.DatabasePort,settings.GamePort,settings.LoginPort}) if(port<1024 || port>65535) throw new Exception("Invalid port");
        Text="Tibia Solo - Stock Canary"; ClientSize=new Size(540,235); FormBorderStyle=FormBorderStyle.FixedDialog; MaximizeBox=false;
        StartPosition=FormStartPosition.CenterScreen;
        var title=new Label { Text="TIBIA SOLO · STOCK",Font=new Font("Segoe UI",20,FontStyle.Bold),Location=new Point(20,18),AutoSize=true };
        status.Location=new Point(23,70); status.Size=new Size(490,60); status.Text="Preparing your local world...";
        var help=new Label { Text="Account: "+settings.Email+"\nPassword: "+settings.Password,Location=new Point(23,137),Size=new Size(490,43) };
        stop.Text="Save and exit"; stop.Location=new Point(360,191); stop.Size=new Size(150,30); stop.Click+=delegate { RequestStop(); };
        Controls.AddRange(new Control[]{title,status,help,stop});
        Shown+=async delegate { await Task.Run((Action)StartWorld); };
        FormClosing+=delegate(object sender,FormClosingEventArgs e) { if(!done) { e.Cancel=true; RequestStop(); } };
    }
    void Log(string message) { lock(logGate) File.AppendAllText(Path.Combine(root,"logs","launcher.log"),DateTime.Now.ToString("s")+" "+message+Environment.NewLine); }
    void SetStatus(string message) { Log(message); if(!IsDisposed && IsHandleCreated) BeginInvoke((Action)delegate { status.Text=message; }); }
    Process Spawn(string exe,string args,string dir,string logName) {
        var p=new Process { StartInfo=new ProcessStartInfo(exe,args) { WorkingDirectory=dir,UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true } };
        DataReceivedEventHandler handler=delegate(object s,DataReceivedEventArgs e) { if(e.Data!=null) lock(logGate) File.AppendAllText(Path.Combine(root,"logs",logName),e.Data+Environment.NewLine); };
        p.OutputDataReceived+=handler; p.ErrorDataReceived+=handler;
        p.Start(); p.BeginOutputReadLine(); p.BeginErrorReadLine(); return p;
    }
    bool PortOpen(int port) { try { using(var c=new TcpClient()) { return c.ConnectAsync("127.0.0.1",port).Wait(250) && c.Connected; } } catch { return false; } }
    void WaitPort(int port,Process p,int seconds) {
        var until=DateTime.UtcNow.AddSeconds(seconds);
        while(DateTime.UtcNow<until) { if(stopping) throw new OperationCanceledException(); if(p.HasExited) throw new Exception("A component stopped. See logs."); if(PortOpen(port)) return; Thread.Sleep(300); }
        throw new Exception("Startup timed out. See logs.");
    }
    string RunDb(string tool,string args,string input) {
        var p=new Process { StartInfo=new ProcessStartInfo(Path.Combine(Bin,tool),"--defaults-extra-file=\""+Path.Combine(root,"db-client.cnf")+"\" --host=127.0.0.1 --port="+settings.DatabasePort+" --user=root "+args) { UseShellExecute=false,CreateNoWindow=true,RedirectStandardInput=true,RedirectStandardOutput=true,RedirectStandardError=true } };
        p.Start(); var output=p.StandardOutput.ReadToEndAsync(); var error=p.StandardError.ReadToEndAsync();
        if(input!=null) p.StandardInput.Write(input); p.StandardInput.Close();
        if(!p.WaitForExit(60000)) throw new Exception("Database operation timed out; save database remains running.");
        if(p.ExitCode!=0) throw new Exception("Database operation failed; see component logs.");
        return output.Result;
    }
    void Backup() {
        string sql=RunDb("mariadb-dump.exe","--single-transaction --routines --events tibiasolostock",null);
        File.WriteAllText(Path.Combine(root,"backups",DateTime.Now.ToString("yyyyMMdd-HHmmss-fff")+".sql"),sql,new UTF8Encoding(false));
    }
    void StartWorld() {
        try {
            foreach(string dir in new[]{"logs","saves","backups"}) Directory.CreateDirectory(Path.Combine(root,dir));
            instanceLock=new FileStream(Path.Combine(root,"saves","session.lock"),FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None);
            foreach(int port in new[]{settings.DatabasePort,settings.GamePort,settings.GamePort-1,settings.GamePort+1,settings.LoginPort}) if(PortOpen(port)) throw new Exception("A local port is in use. No existing process was changed.");
            string stopFile=Path.Combine(ServerDir,"offline-stop"); if(File.Exists(stopFile)) File.Delete(stopFile);
            SetStatus("Starting the local save database...");
            if(stopping) throw new OperationCanceledException();
            database=Spawn(Path.Combine(Bin,"mariadbd.exe"),"--no-defaults --basedir=\""+Path.GetDirectoryName(Bin)+"\" --datadir=\""+Path.Combine(root,"saves","database")+"\" --bind-address=127.0.0.1 --port="+settings.DatabasePort+" --innodb-buffer-pool-size=128M --max-connections=16 --log-error=\""+Path.Combine(root,"logs","database.log")+"\"",root,"database-console.log");
            WaitPort(settings.DatabasePort,database,60); Backup();
            SetStatus("Loading the stock world. First startup can take a minute...");
            if(stopping) throw new OperationCanceledException();
            server=Spawn(Path.Combine(ServerDir,"canary.exe"),"",ServerDir,"server.log");
            WaitPort(settings.GamePort,server,240);
            login=new TcpListener(IPAddress.Loopback,settings.LoginPort); login.Start(); Task.Run((Action)LoginLoop);
            Task.Run(delegate { server.WaitForExit(); if(!stopping) { SetStatus("World stopped unexpectedly; retaining your saves."); RequestStop(); } });
            if(!serverOnly) {
                SetStatus("Ready. Log in using the account shown below.\nClosing the game saves and stops this world.");
                if(stopping) throw new OperationCanceledException();
                client=Spawn(Path.Combine(root,"client","otclient.exe"),"",Path.Combine(root,"client"),"client.log");
                startupFinished.Set(); client.WaitForExit(); RequestStop();
            } else { SetStatus("Ready (server-only verification mode)."); startupFinished.Set(); }
        } catch(OperationCanceledException) { }
        catch(Exception e) { SetStatus(e.Message); RequestStop(); }
        finally { startupFinished.Set(); }
    }
    void LoginLoop() {
        while(!stopping) { try { var conn=login.AcceptTcpClient(); Task.Run(delegate { HandleLogin(conn); }); } catch { break; } }
    }
    void HandleLogin(TcpClient conn) {
        using(conn) try {
            conn.ReceiveTimeout=5000; conn.SendTimeout=5000;
            var stream=conn.GetStream(); var bytes=new List<byte>(); int b; bool complete=false;
            while(bytes.Count<16384 && (b=stream.ReadByte())>=0) { bytes.Add((byte)b); int n=bytes.Count; if(n>=4 && bytes[n-4]==13 && bytes[n-3]==10 && bytes[n-2]==13 && bytes[n-1]==10) { complete=true; break; } }
            if(!complete) return;
            string head=Encoding.ASCII.GetString(bytes.ToArray()); int length=0;
            foreach(string line in head.Split('\n')) if(line.StartsWith("Content-Length:",StringComparison.OrdinalIgnoreCase) && !int.TryParse(line.Substring(15).Trim(),out length)) return;
            if(length<0 || length>16384) return;
            byte[] body=new byte[length]; int read=0;
            while(read<length) { int got=stream.Read(body,read,length-read); if(got==0) return; read+=got; }
            var json=new JavaScriptSerializer(); object response;
            if(head.StartsWith("GET /health ")) response=new {ready=true};
            else if(!head.StartsWith("POST /login ")) response=new {errorCode=3,errorMessage="Unknown local endpoint."};
            else {
                var req=json.Deserialize<Dictionary<string,object>>(Encoding.UTF8.GetString(body));
                if(!req.ContainsKey("email") || Convert.ToString(req["email"])!=settings.Email || !req.ContainsKey("password") || Convert.ToString(req["password"])!=settings.Password) response=new {errorCode=3,errorMessage="Incorrect local account."};
                else {
                    string rows=RunDb("mariadb.exe","--batch --skip-column-names tibiasolostock","SELECT name,level,vocation,looktype,lookhead,lookbody,looklegs,lookfeet FROM players WHERE account_id=100 AND deletion=0 ORDER BY name;");
                    var chars=new List<object>(); string[] voc={"None","Sorcerer","Druid","Paladin","Knight","Master Sorcerer","Elder Druid","Royal Paladin","Elite Knight","Monk"};
                    foreach(string row in rows.Trim().Split('\n')) {
                        var f=row.TrimEnd('\r').Split('\t'); if(f.Length!=8) continue; int v=int.Parse(f[2]);
                        chars.Add(new {name=f[0],level=int.Parse(f[1]),vocation=v<voc.Length?voc[v]:"Adventurer",worldid=0,ismaincharacter=false,ishidden=false,dailyrewardstate=0,outfitid=int.Parse(f[3]),headcolor=int.Parse(f[4]),torsocolor=int.Parse(f[5]),legscolor=int.Parse(f[6]),detailcolor=int.Parse(f[7]),addonsflags=0});
                    }
                    string premium=RunDb("mariadb.exe","--batch --skip-column-names tibiasolostock","SELECT premdays FROM accounts WHERE id=100;").Trim();
                    int days; int.TryParse(premium,out days);
                    response=new {session=new {sessionkey=settings.Email+"\n"+settings.Password,ispremium=days>0,premiumuntil=days>0 ? DateTimeOffset.UtcNow.ToUnixTimeSeconds()+days*86400L : 0,status="active"},playdata=new {worlds=new[]{new {id=0,name="Tibia Solo Stock",externaladdress="127.0.0.1",externalport=settings.GamePort,externaladdressprotected="127.0.0.1",externalportprotected=settings.GamePort,externaladdressunprotected="127.0.0.1",externalportunprotected=settings.GamePort,previewstate=0,pvptype=0}},characters=chars}};
                }
            }
            byte[] payload=Encoding.UTF8.GetBytes(json.Serialize(response));
            byte[] prefix=Encoding.ASCII.GetBytes("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: "+payload.Length+"\r\nConnection: close\r\n\r\n");
            stream.Write(prefix,0,prefix.Length); stream.Write(payload,0,payload.Length);
        } catch { Log("A local login request failed. Credentials were not logged."); }
    }
    void RequestStop() { lock(logGate) { if(stopping) return; stopping=true; } Task.Run((Action)StopWorld); }
    void StopWorld() {
        try {
            SetStatus("Saving and shutting down safely...");
            if(!startupFinished.WaitOne(60000)) throw new Exception("Startup is still stopping. Keep this window open and retry.");
            if(client!=null && !client.HasExited) { client.CloseMainWindow(); if(!client.WaitForExit(15000)) throw new Exception("Please close the game window normally to finish saving."); }
            if(server!=null && !server.HasExited) { File.WriteAllText(Path.Combine(ServerDir,"offline-stop"),"shutdown"); if(!server.WaitForExit(90000)) throw new Exception("World has not confirmed shutdown. It remains running to protect saves; retry."); }
            if(login!=null) login.Stop();
            if(database!=null && !database.HasExited) { Backup(); RunDb("mariadb-admin.exe","shutdown",null); if(!database.WaitForExit(30000)) throw new Exception("Database is still stopping. Keep the window open."); }
            if(instanceLock!=null) instanceLock.Dispose();
            done=true; SetStatus("Saved. All local components stopped."); BeginInvoke((Action)Close);
        } catch(Exception e) { stopping=false; SetStatus(e.Message); }
    }
}
