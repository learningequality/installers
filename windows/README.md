KA Lite Installer for Windows
==========

This project provides a smoother way to install and run KA Lite in a Windows Machine.

---
#### This project was built using the following software:
* Inno Setup 5.5.3 [Download] (http://files.jrsoftware.org/is/5/)
* Microsoft Visual Studio Community 2015 [Website] (https://www.visualstudio.com/)
* Git (note: install with the option to place the `git` executable in the path, so it can be run within `cmd`)

---
#### Instructions to build the GUI:
* Open `gui-source/KA Lite.sln` using Visual Studio.
* Click on the "Build" menu and then choose the "Build Solution" option.
* Copy the resulting `KA Lite.exe` from its output location to `gui-packed/KA Lite.exe`

Note: If you have made no changes to `gui-source`, you don't have to build `KA Lite.exe`. Just use the version in this repo.

Note: If you *do* make changes to anything in `gui-source`, be sure to build and commit `KA Lite.exe`.


---
#### Instructions to build "KALiteSetup.exe":
To build in Linux, first install `wine`.
* Clone this repository;
* Copy `ka-lite` folder from KA Lite's repository, to the root of this repository.
* Using msys shell from MinGW:
  * Set the KALITE_PYTHON variable to an appropriate python interpreter (with the required dependencies). (Hint: use `export`.)
  * Set the PATH variable so that the appropriate interpreter is called when you type "python" in the shell.
  * Go to the included ka-lite repo and run `make dist`.
* Then remove the `node_modules` subdirectory. It causes an error with Inno Setup.
  * If the path name is too long, then [see this SO answer](http://superuser.com/questions/755298/how-to-delete-a-file-with-a-path-too-long-to-be-deleted).
* Delete `secretkey.txt` from `kalite` directory.
* Download the `khan_assessment.zip` file to this directory. Look for it in [the pantry](http://pantry.learningequality.org/downloads/).
* In Windows, run the following command from this directory:
```
> make.vbs
```
* In Linux, run the following command in this directory using `wine`:
```bash
> wine inno-compiler/ISCC.exe installer-source/KaliteSetupScript.iss
```
* The output file named "KALiteSetup-X.X.X.exe" will appear within this project folder.
* Party on, Garth.

---
#### Node on Windows
Get [Node](https://nodejs.org/en/). It should add the `node` and `npm` binaries to your path.

You'll need both `git` and `make` in your PATH to get all the dependencies from npm.
You can get `make` (and many other GNU utilities) with [MinGW](http://www.mingw.org/).
Install it, and then in the `C:\MinGW\bin` directory (or wherever you installed it) you'll find `mingw32-make.exe`.
Make a copy of that file called `make.exe`, and add its directory to your path.

Get [Git](https://git-scm.com/).
Install it and add `c:\Program Files (x86)\Git\bin` (or wherever you installed it) to your path.

After adding both binaries to your path, you're ready to run `npm install` in the `ka-lite` directory.

---
#### To clone ka-lite and this repository, run the following lines:
* git clone https://github.com/learningequality/ka-lite.git
* git clone https://github.com/learningequality/installers.git
