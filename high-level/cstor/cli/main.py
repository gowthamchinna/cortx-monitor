#!/usr/bin/env python2.7
# -*- coding: utf-8 -*-

""" This file acts as the main executable for the Castor CLI
"""

# Do NOT modify or remove this copyright and confidentiality notice

# Copyright 2015 Seagate Technology LLC or one of its affiliates.
#
# The code contained herein is CONFIDENTIAL to Seagate Technology LLC.
# Portions may also be trade secret. Any use, duplication, derivation,
# distribution or disclosure of this code, for any reason, not expressly
# authorized in writing by Seagate Technology LLC is prohibited.
# All rights are expressly reserved by Seagate Technology LLC.

# Import system Modules

# Import Local Modules

from cstor.cli.commands.command_factory import Factory
from cstor.cli.errors import BaseError, CommandTerminated


def main():
    """ Main script to execute the CLI commands and print the
    result back to the terminal.
    -h option should be used to get the help on the usage of
    this script
    """

    try:
        command_obj = Factory.get_subcmd()
        result = command_obj.execute_action()
        if result and isinstance(result, list):
            for item in result:
                print item
        else:
            print result
    except CommandTerminated as extra_info:
        return []
    except BaseError as extra_info:
        print "Error: {}, Desc: {}".format(extra_info.err, extra_info.desc)
    except ValueError as extra_info:
        print "Some error occurred. Details: {}".format(str(extra_info))

if __name__ == '__main__':
    main()
