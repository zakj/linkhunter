#!/usr/bin/env python
# coding: utf-8
# vim:tabstop=20

MESSAGES = '''

add_error_auth	Blast! Time to update your hunting license.
add_error_ajax	Server is playin' hard to get. Try hunting later.
add_error_url	Or not. Your URL blows.
add_error_default	You missed!
add_already	You added this link $1.
add_slow	Waiting for $1…

config_auth_check	Inspecting your hunting license…
config_auth_success	Rounding up your links…
config_auth_fail	Oof! $1 rejected that username/password.

sync_error_connect	Server is playin' hard to get. Try hunting later.
sync_error_auth	Oof! Seems your username/password need some updating.
sync_error_toomany	Seems like you're updatin' too fast for the server!
sync_error_default	Well shucks. Something's busted for serious. ($1)

'''

import argparse
import json


def parse(messages):
    return dict(line.split(None, 1) for line in messages.splitlines() if line)


def chrome(messages):
    chrome_messages = {}
    for k, v in messages.items():
        chrome_messages[k] = {'message': v}
    return json.dumps(chrome_messages)


def safari(messages):
    return 'messages = %s;' % json.dumps(messages)


def main():
    parser = argparse.ArgumentParser(description='Output English messages.')
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--chrome', '-c', action='store_true',
                       help='Output a JSON string suitable for _locales.')
    group.add_argument('--safari', '-s', action='store_true',
                       help='Output a JavaScript object definition.')
    args = parser.parse_args()
    messages = parse(MESSAGES)
    if args.chrome:
        print chrome(messages)
    elif args.safari:
        print safari(messages)


if __name__ == '__main__':
    main()
