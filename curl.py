#!/usr/bin/env python3
# -*- coding: UTF-8 -*-

import requests as rq
import time
import sys
from colorama import Fore, Back, Style

# parameters
AGIC_IP = sys.argv[1]

web_link="http://" + str(AGIC_IP)

HEADERS = {}
READTIMEOUT_COUNT = 0
CONNECTTIMEOUT_COUNT = 0
HTTPERROR_COUNT = 0
UNKNOWNERROR_COUNT = 0

if len(sys.argv) == 3:
    HEADER_HOST = sys.argv[2]
    HEADERS['Host'] = HEADER_HOST

def print_green_on_default(text): return print(Fore.GREEN + text)
def print_blue_on_default(text): return print(Fore.BLUE + text)
def print_red_on_default(text): return print(Fore.RED + text)
def print_yellow_on_default(text): return print(Fore.YELLOW + text)

def main():

    global HEADERS
    global READTIMEOUT_COUNT
    global CONNECTTIMEOUT_COUNT
    global HTTPERROR_COUNT
    global UNKNOWNERROR_COUNT

    while True:

        try:
            if not HEADERS:
                output = rq.get(web_link, verify=False, timeout=(1, 1))
            else:
                output = rq.get(web_link, verify=False, timeout=(1, 1), headers=HEADERS)

        except rq.exceptions.ConnectTimeout:
            CONNECTTIMEOUT_COUNT += 1
            print_red_on_default("Error: Connect Timeout - count: %s" % (str(CONNECTTIMEOUT_COUNT)))

        except rq.exceptions.ReadTimeout:
            READTIMEOUT_COUNT += 1
            print_red_on_default("Error: Read Timeout - count: %s" % (str(READTIMEOUT_COUNT)))

        except rq.exceptions.RequestException as e:
            UNKNOWNERROR_COUNT += 1
            print_red_on_default("Error: %s - count: %s" % (e + str(UNKNOWNERROR_COUNT)))

        if output.status_code == 200:
            result = str.strip(output.text)
            if "v1.0.0" in result:
                print_green_on_default(result)
            elif "v2.0.0" in result:
                print_blue_on_default(result)
            time.sleep(0.1)
        else:
            HTTPERROR_COUNT += 1
            print_red_on_default("Error: Status code is %s - count: %s" % (str(output.status_code), str(HTTPERROR_COUNT)))
        continue


if __name__ == "__main__":
   try:
      main()
   except KeyboardInterrupt:
      # print out the number of errors
      print("")
      print_yellow_on_default("The Amount of Read Timeout: " + str(READTIMEOUT_COUNT))
      print_yellow_on_default("The Amount of Connect Timeout: " + str(CONNECTTIMEOUT_COUNT))
      print_yellow_on_default("The Amount of HTTP Error: " + str(HTTPERROR_COUNT))
      print_yellow_on_default("The Amount of Unknown Error: " + str(UNKNOWNERROR_COUNT))
