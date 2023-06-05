#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

import requests as rq
import time
import sys

# parameters
AGIC_IP = sys.argv[1]

web_link="http://" + str(AGIC_IP)



READTIMEOUT_COUNT = 0
CONNECTTIMEOUT_COUNT = 0
HTTPERROR_COUNT = 0
UNKNOWNERROR_COUNT = 0

def main():

    global READTIMEOUT_COUNT
    global CONNECTTIMEOUT_COUNT
    global HTTPERROR_COUNT
    global UNKNOWNERROR_COUNT

    while True:

        try:
            output = rq.get(web_link, verify=False, timeout=(1, 1))

        except rq.exceptions.ConnectTimeout:
            CONNECTTIMEOUT_COUNT += 1
            print("Error: Connect Timeout - count: %s" % (str(CONNECTTIMEOUT_COUNT)))

        except rq.exceptions.ReadTimeout:
            READTIMEOUT_COUNT += 1
            print("Error: Read Timeout - count: %s" % (str(READTIMEOUT_COUNT)))

        except rq.exceptions.RequestException as e:
            UNKNOWNERROR_COUNT += 1
            print("Error: %s - count: %s" % (e + str(UNKNOWNERROR_COUNT)))

        if output.status_code == 200:
            print(str.strip(output.text))
            time.sleep(0.1)
        else:
            HTTPERROR_COUNT += 1
            print("Error: Status code is %s - count: %s" % (str(output.status_code), str(HTTPERROR_COUNT)))
        continue


if __name__ == "__main__":
   try:
      main()
   except KeyboardInterrupt:
      # print out the number of errors
      print("")
      print("The Amount of Read Timeout: " + str(READTIMEOUT_COUNT))
      print("The Amount of Connect Timeout: " + str(CONNECTTIMEOUT_COUNT))
      print("The Amount of HTTP Error: " + str(HTTPERROR_COUNT))
      print("The Amount of Unknown Error: " + str(UNKNOWNERROR_COUNT))
