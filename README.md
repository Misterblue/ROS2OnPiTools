# ROS2OnPiTools

Tools for building and running ROS2 on [Raspberry Pi] 3.

These are scripts I created to capture all the steps needed to build and run
[ROS2] on my Raspberry Pi 3.
These tools are mostly bash scripts that are used on a clean [Raspian]
installation.
This is as of August 2018 when Raspian is a 32 bit version of Stretch Debian Linux
and [ROS2] had just released [Bouncy Bolson].

Some of the tools are:

## buildROS2OnRaspberryPi3.sh

Script with all the steps to do an initial or update build of ROS2 on the
Raspberry Pi 3.
I have several Pi's so I build on one and then copy the resulting installation
directories to the other systems.
The script is broken into sections that are enabled by script variables so
the steps can be done one at a time in case there are update or compatibility
problems.

[Raspberry Pi]: https://www.raspberrypi.org/
[ROS2]: https://github.com/ros2/ros2/wiki
[Raspian]: https://www.raspberrypi.org/downloads/raspbian/
[Bouncy Bolson]: https://github.com/ros2/ros2/wiki/Release-Bouncy-Bolson
