# `vcpkg-eg-mac` VMs

## Table of Contents

- [`vcpkg-eg-mac` VMs](#vcpkg-eg-mac-vms)
  - [Table of Contents](#table-of-contents)
  - [Basic Usage](#basic-usage)
    - [Cleaning Up](#cleaning-up)
    - [Getting the New Requirements](#getting-the-new-requirements)
    - [Setting up a new macOS machine](#setting-up-a-new-macos-machine)
    - [Troubleshooting](#troubleshooting)
  - [Creating a new Vagrant box](#creating-a-new-vagrant-box)
    - [VM Software Versions](#vm-software-versions)

## Basic Usage

If this is the first time you're setting up a new machine,
follow the instructions in [Setting up a new macOS machine](#setting-up-a-new-macos-machine)
first, then start reading at [Getting the New Requirements](#getting-the-new-requirements).

### Cleaning Up

When starting a new macOS vagrant virtual machine, the first thing to do is to
make certain that any current virtual machine running is shut down and deleted.
If `~/vagrant/vcpkg-eg-mac` exists, you'll want to:

```sh
$ pushd ~/vagrant/vcpkg-eg-mac
$ vagrant destroy -f
$ popd
$ rm -rf ~/vagrant/vcpkg-eg-mac
```

Then, you'll be able to delete any existing boxes, apart from the version that
you need:

```sh
$ vagrant box list
$ vagrant box delete vcpkg/macos-ci --box-version <old-date>
```

After this, you're ready to get the requirements for the new box.

### Getting the New Requirements

First, you'll want to install the prerequisites;
this includes stuff like brew and osxfuse:

```sh
$ ./Install-Prerequisites.ps1
```

This may ask for your password.
This is because we need to use `sudo` to install some pieces of software.

Next, let's try to mount the fileshare,
so that we can get the new box for the VM.

```sh
$ sshfs fileshare@<fileshare-machine>:share ~/vagrant/share
```

If this succeeds, you're good.
Otherwise, you may have to go through the [troubleshooting steps](#troubleshooting:sshfs).

Once you've gotten `share` mounted, you'll be able to add the box to vagrant.

```sh
$ vagrant box add ~/vagrant/share/boxes/macos-ci.json --box-version <date-of-box>
```

This will take a while. We suggest using tmux to do this, so as to avoid the connection dropping.

Once this is finished, you'll have everything you need to set up the VM and run it.
Parallels is kinda weird, and it requires the GUI to be logged into;
so, KVM in and log in for just this part (you can still run everything from SSH).
Grab a PAT with manage access to agent pools from the Azure website,
and finally run:

```sh
$ ./Setup-VagrantMachines.ps1 -Date <date-of-box> -DevopsPat <pat>
$ cd ~/vagrant/vcpkg-eg-mac
$ vagrant up
```

And then you should be finished!

### Setting up a new macOS machine

Before anything else, one must download `brew` and `powershell`.

```sh
$ /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
$ brew cask install powershell
```

Then, we need to download the `vcpkg` repository:

```sh
$ git clone https://github.com/microsoft/vcpkg
```

Then, we need to mint an SSH key:

```sh
$ ssh-keygen
$ cat .ssh/id_rsa.pub
```

Add that SSH key to `authorized_keys` on the file share machine with the base box.

After this, you can follow the instructions for setting up a virtual machine in
(Basic Usage)[#basic-usage].

### Troubleshooting

- <a name="troubleshooting:sshfs" /> When running `sshfs`, a kernel module is required.
  macOS requires kernel modules to be approved by the GUI.
  Log in to the machine, open System Preferences > Security & Privacy > General,
  and allow system extensions from the osxfuse developer to run.
  Then, reboot the machine.

## Creating a new Vagrant box

Whenever we want to install updated versions of the command line tools,
or of macOS, we need to create a new vagrant box.
This is pretty easy, but the results of the creation are not public,
since we're concerned about licensing.
However, if you're sure you're following Apple's licensing,
you can set up your own vagrant boxes that are the same as ours by doing the following:

You'll need some prerequisites:

- vagrant - found at <https://www.vagrantup.com/>
  - The vagrant-parallels plugin - `vagrant plugin install vagrant-parallels`
- Parallels - found at <https://parallels.com>
- An Xcode installer - you can get this from Apple's developer website,
  although you'll need to sign in first: <https://developer.apple.com/downloads>

First, you'll need to create a base VM;
this is where you determine what version of macOS is installed.
Just follow the Parallels process for creating a macOS VM.

Once you've done this, you can run through the installation of macOS onto a new VM.
You should set the username to `vagrant`.

Once it's finished installing, make sure to turn on the SSH server.
Open System Preferences, then go to Sharing > Remote Login,
and turn it on.
You'll then want to add the vagrant SSH keys to the VM's vagrant user.
Open the terminal application and run the following:

```sh
$ # basic stuff
$ date | sudo tee '/etc/vagrant_box_build_time'
$ printf 'vagrant\tALL=(ALL)\tNOPASSWD:\tALL\n' | sudo tee -a '/etc/sudoers.d/vagrant'
$ sudo chmod 0440 '/etc/sudoers.d/vagrant'
$ # then install vagrant keys
$ mkdir -p ~/.ssh
$ curl -fsSL 'https://raw.github.com/mitchellh/vagrant/master/keys/vagrant.pub' >~/.ssh/authorized_keys
$ chmod 0600 ~/.ssh/authorized_keys
```

Finally, you'll need to install the Parallel Tools.
From your host, in the top bar,
go to Actions > Install Parallels Tools...,
and then follow the instructions.

Now, let's package the VM into a base box.
(The following instructions are adapted from
[these official instructions][base-box-instructions]).

Run the following commands:

```sh
$ cd ~/Parallels
$ echo '{ "provider": "parallels" }' >metadata.json
$ tar zgvf <current date>.box ./metadata.json ./<name of VM>.pvm
```

This will create a box file which contains all the necessary data.
You can delete the `metadata.json` file after.

Once you've done that, you can upload it to the fileshare,
under `share/boxes/vcpkg-ci-base`, add it to `share/boxes/vcpkg-ci-base.json`,
and finally add it to vagrant:

```sh
$ vagrant box add ~/vagrant/share/boxes/vcpkg-ci-base.json
```

Then, we'll create the final box,
which contains all the necessary programs for doing CI work.
Copy `configuration/Vagrantfile-box.rb` as `Vagrantfile`, and
`configuration/vagrant-box-configuration.json`
into a new directory; into that same directory,
download the Xcode command line tools dmg, and name it `clt.dmg`.
Then, run the following in that directory:

```sh
$ vagrant up
$ vagrant package
```

This will create a `package.box`, which is the box file for the base VM.
Once you've created this box, if you're making it the new box for the CI,
upload it to the fileshare, under `share/boxes/vcpkg-ci`.
Then, add the metadata about the box (the name and version) to
`share/boxes/vcpkg-ci.json`.
Once you've done that, add the software versions under [VM Software Versions](#vm-software-versions).

[base-box-instructions]: https://parallels.github.io/vagrant-parallels/docs/boxes/base.html

### VM Software Versions

* 2020-09-28:
  * macOS: 10.15.6
  * Xcode CLTs: 12
* 2021-04-16:
  * macOS: 11.2.3
  * Xcode CLTs: 12.4
* 2021-07-01:
  * macOS: 
  * Xcode CLTs:
