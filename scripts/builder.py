#!/usr/bin/env python3

import os
import fcntl
import sys
import datetime
import subprocess
import threading

def run(bash, color):
  class ThreadWorker(threading.Thread):
    def __init__(self, pipe):
      super(ThreadWorker, self).__init__()
      self.pipe = pipe
      self.setDaemon(True)

    def run(self):
      for line in iter(self.pipe.readline, b''):
        p(">>> " + line.decode("utf-8"), color=color, end='')


  proc = subprocess.Popen(bash, stdin=None, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0, shell=True)
  stdout_worker = ThreadWorker(proc.stdout)
  stderr_worker = ThreadWorker(proc.stderr)
  stdout_worker.start()
  stderr_worker.start()

  proc.wait()
  stdout_worker.join()
  stderr_worker.join()

def consolecode(color):
  return "\u001B[" + str(color) + "m"

FIRST, LAST, WHITE, RED = 31, 37, 0, 32
color = FIRST
def nextcolor():
  global color
  color = color + 1
  if color == LAST:
    color = FIRST
  return color

def p(s, end=None, color=WHITE):
  date = datetime.datetime.now().strftime("%H:%M:%S:%f")
  date = ""
  newline = ""
  if s[0] == "\n":
    s = s[1:]
    newline = "\n"
  print(newline + consolecode(color) + date + ": " + s, end=end)
  sys.stdout.flush()

def call(bash):
  color = nextcolor()
  p("$ " + bash, color=color)
  run(bash, color=color)
  p("X " + bash, color=color)

def reload_server():
  call("scripts/runserver")

def reload_browser():
  # Sends a signal to another fswatch on your mac
  call("touch .browser_trigger")

def ignore(filename, reason):
  if reason == "IsDir":
    return True
  if reason == "PlatformSpecific":
    return True

  # substring
  ignores = [".git", "scripts/", "logs/", "appdata/"]
  ignores += ["client/elm-stuff", "static/elm.js"]
  ignores += ["ocamlserver/" + i for i in ["setup.log",
                                           "setup.data",
                                           "_build",
                                           "_tags",
                                           "myocamlbuild.ml",
                                           "Makefile"]]
  for i in ignores:
    if i in filename:
      return True
  # ocaml build temporary
  if filename[-10:-8] == "/C":
    return True
  # emacs thing
  if "/.#" in filename:
    return True
  return False

def main():
  p("Starting")
  for f in sys.stdin:
    (f, reason) = f.strip().split(" ")
    if ignore(f, reason):
      continue

    p("\nDetected change (" + reason + "): " + f)

    # Server
    if "main.byte" in f or "main.native" in f:
      # ignore the trigger, the compile methods call this direct
      pass

    # Frontend
    elif ".elm" in f:
      call("cd client && elm-make Main.elm --debug --output ../static/elm.js")
      reload_browser();


    # Ocaml
    elif "_oasis" in f:
      call("cd ocamlserver && oasis setup -setup-update dynamic && make")
      reload_server()
      reload_browser();
    elif ".ml" in f:
      call("cd ocamlserver && make")
      reload_server()
      reload_browser();

    # Other
    else:
      p("unknown file: " + f, end="")

  p("Done")

main()
