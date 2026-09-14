# MENU: Demo — AWK
# DESCRIPTION: AWK example showing metadata and ASK through ENVIRON
# CONFIRM: false
# TERMINAL: false
# SUDO: false
# ORDER: 120
# ASK: Demo value
# ICON: ../assets/demo-blue.svg

BEGIN {
    value = ENVIRON["SCRIPTYA_ASK_1"]
    if (value == "") value = (ARGC > 1 ? ARGV[1] : "demo")
    print "AWK_DEMO_OK|" value
    exit 0
}
