(defpackage :bluetooth
  (:use #:cl
        #:alexandria
        #:stumpwm)
  (:import-from #:uiop
                #:strcat)
  (:export
   ;; Variables
   *bluetooth-path*
   *check-interval*
   *modeline-fmt*
   *formatters-alist*
   ;; Commands
   bluetooth-toggle-power
   bluetooth-power-on
   bluetooth-power-off
   bluetooth-connect
   bluetooth-disconnect
   bluetooth-toggle-device
   bluetooth-pair
   bluetooth-remove
   bluetooth-scan
   bluetooth-open-manager
   bluetooth-select-device
   ;; Functions
   init
   update-info
   modeline))

(in-package :bluetooth)

;; formatters
(add-screen-mode-line-formatter #\Y 'modeline)

(defparameter *check-interval* 3
  "Interval in seconds to update bluetooth status")

(defparameter *modeline-fmt* "%p %d"
  "The default value for displaying bluetooth information on the modeline.
   Available formatters:
   %p - power status (ON/OFF)
   %d - connected device name
   %i - connected device icon
   %n - number of connected devices")

(defparameter *formatters-alist*
  '((#\p ml-power)
    (#\d ml-device)
    (#\n ml-num-devices)))

(defparameter *bluetooth-path* "/usr/bin/bluetoothctl")
(defparameter *bluetooth-manager-command* "blueman-manager")

;; State variables
(defvar *power-state* nil)
(defvar *connected-devices* nil
  "List of connected devices as alists:
((name . \"Device Name\") (mac . \"XX:XX:XX:XX:XX:XX\"))")
(defvar *paired-devices* nil
  "List of paired devices as alists")
(defvar *scan-results* nil
  "List of discovered devices during scan")

;; Regex patterns
(defvar *device-regex*
  (ppcre:create-scanner "^Device\\s+([0-9A-Fa-f:]+)\\s+(.+)$"))

(defvar *power-regex*
  (ppcre:create-scanner "\\bPowered:\\s*(yes|no)\\n"))

(defvar *connected-regex*
  (ppcre:create-scanner "\\bConnected:\\s*(yes|no)\\n"))

(defvar *name-regex*
  (ppcre:create-scanner "\\bName:\\s*(.+)\\n"))

(defvar *icon-regex*
  (ppcre:create-scanner "\\bIcon:\\s*(.+)\\n"))


(defun run (args &optional (wait-output nil))
  "Run bluetoothctl with given arguments.
   If wait-output is non-nil, capture and return the output."
  (if wait-output
      (with-output-to-string (s)
        (sb-ext:run-program *bluetooth-path* args :wait t :output s))
      (sb-ext:run-program *bluetooth-path* args :wait nil)))

(defun trim-whitespace (str)
  "Trim leading and trailing whitespace from string."
  (string-trim '(#\Space #\Tab #\Newline #\Return) str))

(defun parse-devices-list (output)
  "Parse the output of 'devices' command into a list of alists."
  (let ((devices '()))
    (ppcre:do-register-groups (mac name)
        (*device-regex* output)
      (push `((mac . ,mac)
              (name . ,(trim-whitespace name)))
            devices))
    (nreverse devices)))

(defun get-device-info (mac)
  "Get detailed info for a device by MAC address."
  (let ((output (run (list "info" mac) t)))
    (ppcre:register-groups-bind (name)
        (*name-regex* output)
      (ppcre:register-groups-bind (icon)
          (*icon-regex* output)
        (ppcre:register-groups-bind (connected)
            (*connected-regex* output)
          `((mac . ,mac)
            (name . ,name)
            (icon . ,icon)
            (connected . ,(and connected (string= connected "yes")))))))))

(defun update-power-state ()
  "Update the power state of the bluetooth adapter."
  (when-let ((output (run '("show") t)))
    (ppcre:register-groups-bind (state)
        (*power-regex* output)
      (setf *power-state* (string= state "yes")))))

(defun update-paired-devices ()
  "Update the list of paired devices."
  (let* ((output (run '("devices" "Paired") t)))
    (setf *paired-devices* (parse-devices-list output))))

(defun update-connected-devices ()
  "Update the list of connected devices."
  (let* ((output (run '("devices" "Connected") t)))
    (setf *connected-devices* (parse-devices-list output))))

(defun update-info ()
  "Update all bluetooth state information."
  (update-power-state)
  (update-connected-devices))

(defun power-on ()
  "Turn on the bluetooth adapter."
  (run '("power" "on") t))

(defun power-off ()
  "Turn off the bluetooth adapter."
  (run '("power" "off") t))

(defun toggle-power ()
  "Toggle the bluetooth adapter power state."
  (if *power-state*
      (power-off)
      (power-on))
  (run-with-timer 1 nil
                  #'update-power-state))

(defun connect-device (mac)
  "Connect to a device by MAC address."
  (run (list "connect" mac) t))

(defun disconnect-device (mac)
  "Disconnect from a device by MAC address."
  (run (list "disconnect" mac) t))

(defun toggle-device-connection (mac)
  "Toggle connection to a device. Connect if disconnected, disconnect if connected."
  (let ((device (find mac *paired-devices*
                      :test #'string=
                      :key (rcurry #'assoc-value 'mac))))
    (if device
        (if (cdr (assoc 'connected device))
            (disconnect-device mac)
            (connect-device mac))
        (connect-device mac)))
  (update-connected-devices))

(defun pair-device (mac)
  "Pair with a device by MAC address."
  (run (list "pair" mac) t))

(defun remove-device (mac)
  "Remove a paired device."
  (run (list "remove" mac) t))

(defun start-scan ()
  "Start scanning for bluetooth devices."
  (run '("scan" "on")))

(defun stop-scan ()
  "Stop scanning for bluetooth devices."
  (run '("scan" "off") t))

(defun get-scan-results ()
  "Get list of discovered devices from current scan."
  (let* ((output (run '("devices") t))
         (devices (parse-devices-list output)))
    (setf *scan-results*
          (mapcar (lambda (dev)
                    (or (get-device-info (assoc-value dev 'mac))
                        dev))
                  devices))))

(defun ml-power (power devices)
  "Format power status for modeline."
  (declare (ignore devices))
  (if power "ON" "OFF"))

(defun ml-device (power devices)
  "Format connected device name for modeline."
  (declare (ignore power))
  (if (and devices (car devices))
      (or (assoc-value (car devices) 'name)
          "")
      "---"))

(defun ml-num-devices (power devices)
  "Format number of connected devices for modeline."
  (declare (ignore power))
  (format nil "~d" (length devices)))

(defun modeline (ml)
  "Generate the modeline string for bluetooth."
  (declare (ignore ml))
  (let ((ml-str (format-expand *formatters-alist*
                               *modeline-fmt*
                               *power-state*
                               *connected-devices*)))
    (if (fboundp 'stumpwm::format-with-on-click-id)
        (format-with-on-click-id ml-str :ml-bluetooth-on-click nil)
        ml-str)))

(defun select-device (devices prompt)
  (select-from-menu (current-screen)
                    (mapcar (lambda (dev)
                              (cons (assoc-value dev 'name)
                                    (assoc-value dev 'mac)))
                            devices)
                    prompt))

;; Commands
(defcommand bluetooth-toggle-power () ()
  "Toggle the bluetooth adapter power state."
  (toggle-power)
  (stumpwm::update-all-mode-lines))

(defcommand bluetooth-power-on () ()
  "Turn on the bluetooth adapter."
  (power-on)
  (update-power-state)
  (stumpwm::update-all-mode-lines))

(defcommand bluetooth-power-off () ()
  "Turn off the bluetooth adapter."
  (power-off)
  (update-power-state)
  (stumpwm::update-all-mode-lines))

(defcommand bluetooth-select-device () ()
  "Select a paired device to connect/disconnect."
  (update-paired-devices)
  (if (null *paired-devices*)
      (message "No paired devices found.")
      (when-let ((selection (select-device *paired-devices* "Select device:")))
        (toggle-device-connection (cdr selection))
        (stumpwm::update-all-mode-lines))))

(defcommand bluetooth-connect () ()
  "Connect to a paired device."
  (update-paired-devices)
  (if (null *paired-devices*)
      (message "No disconnected paired devices found.")
      (when-let ((selection (select-device *paired-devices* "Select device to connect:")))
        (connect-device (cdr selection))
        (update-connected-devices)
        (stumpwm::update-all-mode-lines))))

(defcommand bluetooth-disconnect () ()
  "Disconnect from a connected device."
  (update-connected-devices)
  (if (null *connected-devices*)
      (message "No connected devices.")
      (when-let ((selection (select-device *connected-devices* "Select device to disconnect:")))
        (disconnect-device (cdr selection))
        (update-connected-devices)
        (stumpwm::update-all-mode-lines))))

(defcommand bluetooth-toggle-device () ()
  "Toggle connection to a selected device."
  (bluetooth-select-device))

(defcommand bluetooth-pair () ()
  "Pair with a new device. Start scanning first if no devices found."
  (update-paired-devices)
  (let ((available (get-scan-results)))
    (let ((unpaired (remove-if (lambda (dev)
                                 (member (assoc-value dev 'mac)
                                         *paired-devices*
                                         :test #'string=
                                         :key (rcurry #'assoc-value 'mac)))
                               available)))
      (if (null unpaired)
          (message "No new devices found. Try running bluetooth-scan first.")
          (when-let ((selection (select-device unpaired "Select device to pair:")))
            (pair-device (cdr selection))
            (update-paired-devices)
            (stumpwm::update-all-mode-lines))))))

(defcommand bluetooth-remove () ()
  "Remove a paired device."
  (update-paired-devices)
  (if (null *paired-devices*)
      (message "No paired devices.")
      (when-let ((selection (select-device *paired-devices* "Select device to remove:")))
        (remove-device (cdr selection))
        (update-paired-devices)
        (stumpwm::update-all-mode-lines))))

(defcommand bluetooth-scan () ()
  "Scan for bluetooth devices for a few seconds."
  (message "Scanning for bluetooth devices...")
  (start-scan)
  (run-with-timer 5 nil
                  (lambda ()
                    (stop-scan)
                    (get-scan-results)
                    (message "Found ~d device:~%~{~a~^~%~}" (length *scan-results*)
                             (mapcar (lambda (dev)
                                       (format nil "~A - (~A)" (assoc-value dev 'name) (assoc-value dev 'mac)))
                                     *scan-results*)))))

(defcommand bluetooth-open-manager () ()
  "Open the bluetooth manager GUI."
  (run-shell-command *bluetooth-manager-command*))

(defun ml-on-click (code id &rest rest)
  "Handle mouse clicks on the bluetooth modeline."
  (declare (ignore rest id))
  (let ((button (stumpwm::decode-button-code code)))
    (case button
      ((:left-button) (bluetooth-toggle-power))
      ((:right-button) (bluetooth-select-device))
      ((:middle-button) (bluetooth-open-manager))))
  (stumpwm::update-all-mode-lines))

(when (fboundp 'stumpwm::register-ml-on-click-id)
  (register-ml-on-click-id :ml-bluetooth-on-click #'ml-on-click))

(defun init ()
  "Initialize the bluetooth module. Call this from your stumpwmrc."
  (update-info)
  (run-with-timer 0 *check-interval*
                  (lambda ()
                    (bt:make-thread #'update-info
                                    :name "bluetooth-update-info"))))
