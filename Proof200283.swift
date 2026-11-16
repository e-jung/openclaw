import AppKit
import WebKit
let root = "/tmp/openclaw-proof-200283"
try! FileManager.default.createDirectory(atPath: root, withIntermediateDirectories: true)
func log(_ s:String) { let p=root+"/native-events.jsonl";if !FileManager.default.fileExists(atPath:p){FileManager.default.createFile(atPath:p,contents:nil)};let f=FileHandle(forWritingAtPath:p)!;f.seekToEndOfFile();f.write((s+"\n").data(using:.utf8)!);try? f.close() }
class Handler:NSObject,WKScriptMessageHandler {func userContentController(_ u:WKUserContentController,didReceive m:WKScriptMessage){if let s=m.body as? String{log(s)}}}
let app=NSApplication.shared
app.setActivationPolicy(.regular)
let config=WKWebViewConfiguration();let handler=Handler();config.userContentController.add(handler,name:"proof")
config.userContentController.addUserScript(WKUserScript(source:"window.WebSocket = new Proxy(window.WebSocket,{construct(T,args){const s=new T(...args);window.proofSocket=s;return s}})",injectionTime:.atDocumentStart,forMainFrameOnly:true))
let js="""
(()=>{const key='proofEvents';const emit=o=>{let a=JSON.parse(sessionStorage.getItem(key)||'[]');a.push(o);sessionStorage.setItem(key,JSON.stringify(a));window.webkit.messageHandlers.proof.postMessage(JSON.stringify(o));};emit({type:'load',time:Date.now(),path:location.pathname,nav:performance.getEntriesByType('navigation')[0]?.type});for(const type of ['pointerdown','mousedown','mouseup','click','contextmenu']){document.addEventListener(type,e=>{const a=e.target.closest?.('a.sidebar-recent-session__link');if(!a)return;emit({type,phase:'capture',time:Date.now(),button:e.button,ctrlKey:e.ctrlKey,metaKey:e.metaKey,defaultPrevented:e.defaultPrevented,href:a.getAttribute('href')});setTimeout(()=>emit({type,phase:'after',time:Date.now(),defaultPrevented:e.defaultPrevented,menu:!!document.querySelector('.session-menu')}),0);},true)}addEventListener('beforeunload',()=>emit({type:'beforeunload',time:Date.now(),path:location.pathname}));})();
"""
config.userContentController.addUserScript(WKUserScript(source:js,injectionTime:.atDocumentEnd,forMainFrameOnly:true))
let web=WKWebView(frame:.zero,configuration:config);web.isInspectable=true
let window=NSWindow(contentRect:NSRect(x:50,y:50,width:1200,height:800),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
window.title="Isolated Control UI Proof #200283";window.contentView=web;window.makeKeyAndOrderFront(nil);app.activate(ignoringOtherApps:true)
var last=""
let timer=Timer.scheduledTimer(withTimeInterval:0.3,repeats:true){_ in
 if let data=try? Data(contentsOf:URL(fileURLWithPath:root+"/command.json")),let c=try? JSONSerialization.jsonObject(with:data) as? [String:String],let id=c["id"],id != last {last=id
 if let url=c["url"]{web.load(URLRequest(url:URL(string:url)!))}
 if let code=c["js"] {web.evaluateJavaScript(code){v,e in let out:[String:Any]=["id":id,"value":v ?? NSNull(),"error":e?.localizedDescription ?? ""];if let d=try? JSONSerialization.data(withJSONObject:out,options:[.prettyPrinted,.sortedKeys]) {try? d.write(to:URL(fileURLWithPath:root+"/result.json"))}}}
 }
}
app.run()
