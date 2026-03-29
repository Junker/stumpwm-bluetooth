(asdf:defsystem #:bluetooth
  :description "StumpWM module for controlling Bluetooth devices"
  :author "Dmitrii Kosenkov"
  :license "GPLv3"
  :depends-on (#:stumpwm
               #:alexandria
               #:cl-ppcre
               #:bordeaux-threads)
  :serial t
  :components ((:file "bluetooth")))
