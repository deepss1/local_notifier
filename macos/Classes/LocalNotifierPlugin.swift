import Cocoa
import FlutterMacOS
import UserNotifications

public class LocalNotifierPlugin: NSObject, FlutterPlugin, NSUserNotificationCenterDelegate, UNUserNotificationCenterDelegate {
    var registrar: FlutterPluginRegistrar!;
    var channel: FlutterMethodChannel!
    
    var notificationDict: Dictionary<String, NSUserNotification> = [:]
    
    public override init() {
        super.init()
        if #available(macOS 10.14, *) {
            UNUserNotificationCenter.current().delegate = self
        } else {
            NSUserNotificationCenter.default.delegate = self
        }
    }
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "local_notifier", binaryMessenger: registrar.messenger)
        let instance = LocalNotifierPlugin()
        instance.registrar = registrar
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch (call.method) {
        case "notify":
            notify(call, result: result)
            break
        case "close":
            close(call, result: result)
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    public func notify(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! Dictionary<String, Any>
        let identifier: String = args["identifier"] as! String
        let title: String = args["title"] as! String
        let body: String = args["body"] as! String
        
        if #available(macOS 10.14, *) {
            let notification = UNMutableNotificationContent()
            notification.title = title
            notification.body = body
            notification.sound = UNNotificationSound.default
            
            let notificationCenter = UNUserNotificationCenter.current()
            
            let actions: [NSDictionary]? = args["actions"] as? [NSDictionary];
            
            if (actions != nil && !(actions!.isEmpty)) {
                let actionDict =  actions!.first as! [String: Any]
                let actionText: String? = actionDict["text"] as? String
                if ( actionText != nil ) {
                    let action = UNNotificationAction(identifier: "action_identifier", title: actionText!, options: [])
                    
                    let category = UNNotificationCategory(identifier: "category_identifier", actions: [action], intentIdentifiers: [])
                    
                    notification.categoryIdentifier = "category_identifier"
                    notificationCenter.setNotificationCategories([category])
                }
            }
            
            let request = UNNotificationRequest(identifier: identifier, content: notification, trigger: nil)
            
            notificationCenter.add(request) { error in
              if (error != nil) {
                print("quick_notify error: \(error!)")
              }
            }
        } else {
            let subtitle: String? = args["subtitle"] as? String
            let notification = NSUserNotification()
            notification.title = title
            notification.informativeText = body
            notification.identifier = identifier
            notification.subtitle = subtitle
            notification.soundName = NSUserNotificationDefaultSoundName
            notification.contentImage = NSImage(named: NSImage.Name("AppIcon"))
            
            let actions: [NSDictionary]? = args["actions"] as? [NSDictionary];
            
            if (actions != nil && !(actions!.isEmpty)) {
                let actionDict =  actions!.first as! [String: Any]
                let actionText: String? = actionDict["text"] as? String
                notification.actionButtonTitle = actionText!
            }
            
            NSUserNotificationCenter.default.deliver(notification)
        }
        
        result(true)
    }
    
    public func close(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as! Dictionary<String, Any>
        let identifier: String = args["identifier"] as! String
        
        let notification: NSUserNotification? = self.notificationDict[identifier]
        
        if (notification != nil) {
            NSUserNotificationCenter.default.removeDeliveredNotification(notification!)
            self.notificationDict[identifier] = nil
            
            _invokeMethod("onLocalNotificationClose", identifier)
        }
        result(true)
    }

    public func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        switch notification.activationType {
        case .actionButtonClicked:
            _invokeMethod("onLocalNotificationClickAction", notification.identifier!)
        default:
            _invokeMethod("onLocalNotificationClick", notification.identifier!)
        }
    }

    /* public func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
        _invokeMethod("onLocalNotificationClick", notification.identifier!)
    } */
    
    public func userNotificationCenter(_ center: NSUserNotificationCenter, didDeliver notification: NSUserNotification) {
        _invokeMethod("onLocalNotificationShow", notification.identifier!)
    }
    
    public func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }
    
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
           didReceive response: UNNotificationResponse,
           withCompletionHandler completionHandler:
             @escaping () -> Void) {
        
       // Perform the task associated with the action.
       switch response.actionIdentifier {
       case "action_identifier":
           _invokeMethod("onLocalNotificationClickAction", response.notification.request.identifier)
          break
            
       // Handle other actions…
     
       default:
          break
       }
        
       // Always call the completion handler when done.
       completionHandler()
    }
    
    public func _invokeMethod(_ methodName: String, _ notificationId: String) {
        let args: NSDictionary = [
            "notificationId": notificationId,
        ]
        channel.invokeMethod(methodName, arguments: args, result: nil)
    }
}
