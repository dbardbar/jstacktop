# jstacktop
Combine per-thread CPU usage with output of Java's jstack

Java's jstack utility displays great information per thread including thread name and current back trace, but lacks information about actual CPU usage.

Linux's top shows CPU usage per thread, but obviosuly is unaware of Java-specific info.

jstacktop comes to bridge this gap. It runs jstacktop and calculated CPU usage per thread based on /proc. It then outputs something very similar to jstack output, but with CPU% per thread.

# Usage:
Usage: fstool jstacktop [pid] -s
        -s - suppress stacks with 0% CPU


# Example:
``
[root@db]# **jstacktop 24348**

2018-12-24 11:06:53
Full thread dump Java HotSpot(TM) 64-Bit Server VM (25.181-b13 mixed mode):

JNI global references: 2439

"main" #1 prio=5 os_prio=0 tid=0x00007fc06c01e800 nid=0x5f2a in Object.wait() [0x00007fc075a8f000] **%CPU 0**
    java.lang.Thread.State: WAITING (on object monitor)
        at java.lang.Object.wait(Native Method)
        - waiting on <0x000000078557dfc0> (a java.lang.UNIXProcess)
        at java.lang.Object.wait(Object.java:502)
        at java.lang.UNIXProcess.waitFor(UNIXProcess.java:395)
        [... output cropped ...]
``

# Credit
Written mainly by Avi Maslati. Thanks Avi!
