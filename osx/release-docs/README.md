KA-Lite Mac OSX App
===========================

This is the KA-Lite application that sits on the status menu of Mac OSX.  

It's used to install and monitor the [KA-Lite](https://github.com/learningequality/ka-lite/) server by [Foundation for Learning Equality](https://learningequality.org/).

It uses [PyRun](http://www.egenix.com/products/python/PyRun/) to isolate the KA-Lite environment from your system's [Python](https://www.python.org/) application.


## To Install

1. Double the downloaded `KA-Lite.pkg` package and follow the setup wizard.
1. Launch `KA-Lite` from your `Applications` folder.
1. Click on `KA-Lite` icon in menu bar and select the `Start KA-Lite` menu option.
1. When prompted that `KA-Lite` has been started, click on the icon again and select `Open in Browser` menu option - this should launch `KA-Lite` on your preferred web browser.
1. You will be prompted to create admin user in a modal dialog, just specify your `username` and `password` then click on `Create` button.


## Menu Options

1. `Start KA Lite` == Starts the `KA-Lite` web server.
1. `Stop KA Lite` == Stops the `KA-Lite` web server.
1. `Open in Browser` == Opens the installed `KA-Lite` web app using your preferred web browser, usually at `http://127.0.0.1:8008`.
1. `Preferences` == Opens the preferences window where you can customize the `KA-Lite` data path or view logs in `Logs` tab.
1. `Quit` == Stops the `KA-Lite` web server and closes the application.

## Set custom `KA Lite` data path:

 1. Stop the server from running.
 2. Set your custom path in `Preferences` dialog.
 3. Click `Apply`.
 4. Go to terminal and run command `kalite manage syncdb --noinput`.
 5. Run `kalite manage init_content_items --overwrite`.
 6. Run `kalite manage setup --noinput`.
 7. Start the server again by clicking on `Start KA Lite` in the menu option.


## Uninstaller
   
* `KA-Lite_Uninstall.tool` and `KA-Lite.app` are bundled in `/Applications/KA-Lite/` folder.  
* Double clicking on `KA-Lite_Uninstall.tool` does the following:
  - uninstall `KA-Lite.app` and it's dependencies. 
  - optionally remove the `KA-Lite` data path.


## Help and Logs

To view the KA-Lite's application logs (for debugging or tracing), launch the `Console` application and filter by "ka-lite".

You can also view KA-Lite logs on `Preferences` dialog by clicking on the `Logs` tab.

You can also open `~/.kalite/server.log` to view access and debug logs of the KA-Lite server.

If you encounter issues, please file them at the [KA-Lite Installers repository](https://github.com/learningequality/installers).

Please note that we have tested this application on `MAC OSX El Capitan 10.11.1`.


## ToDos

1. Check for updates automatically.
1. Confirm the Quit action with a dialog to prevent accidental closing of the application.