#! /bin/ksh

VERSION="Version 0.5"
AUTHOR="Andreas Karfusehr (andreas@karfusehr.de)"

PROGNAME=`/usr/bin/basename $0`

# Constants
BYTES_IN_MB=$(( 1024 * 1024 ))
KB_IN_MB=1024

# Exit codes
STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

# Helper functions #############################################################

function print_revision {
   # Print the revision number
   echo "$PROGNAME - $VERSION"
}

function print_usage {
   # Print a short usage statement
   echo "Usage: $PROGNAME [-v] -w <limit> -c <limit>"
}

function print_help {
   # Print detailed help information
   print_revision
   echo "$AUTHOR\n\nCheck temperature and cpufreq on your local Raspberry PI\n"
   print_usage

   /bin/cat <<__EOT

Options:
-h
   Print detailed help screen
-V
   Print version information

-w INTEGER
   Exit with WARNING status if less than INTEGER
-w PERCENT%
   Exit with WARNING status if less than PERCENT
-c INTEGER
   Exit with CRITICAL status if less than INTEGER
-c PERCENT%
   Exit with CRITICAL status if less than PERCENT
-v
   Verbose output
__EOT
}

function get_temperature {
    temp=$(($(</sys/class/thermal/thermal_zone0/temp) / 1000))
    #temp=51

    if [[ -z "$thresh_warn" || -z "$thresh_crit" ]]; then
       # One or both thresholds were not specified
       echo "$PROGNAME: Threshold not set"
       print_usage
       exit $STATE_UNKNOWN
    elif [[ "$thresh_warn" -gt "$thresh_crit" ]]; then
       # The warning threshold must be greater than the critical threshold
       echo "$PROGNAME: Warning free space should be more than critical free space"
       print_usage
       exit $STATE_UNKNOWN
    fi

    # Get performance data for Shinken/Icinga or whatever you use. "Performance Data" field
    # PERFDATA=`${SENSORPROG} | grep "$sensor" | head -n1`

    if [[ "$temp" -gt "$thresh_crit" ]]; then
       # Free memory is less than the critical threshold
       echo "CRITICAL - $temp °C CPU temperature is to high | temperature=$temp;$thresh_warn;$thresh_crit;0;1200"
       exit $STATE_CRITICAL
    elif [[ "$temp" -gt "$thresh_warn" ]] && [[ "$temp" -lt "$thresh_crit" ]]; then
       # Free memory is less than the warning threshold
       echo "WARNING - CPU temperature is $temp °C | temperature=$temp;$thresh_warn;$thresh_crit;0;1200"
       exit $STATE_WARNING
    else
       # There's no error
       echo "OK - CPU temperature is $temp °C | temperature=$temp;$thresh_warn;$thresh_crit;0;1200"
       exit $STATE_OK
    fi
}

function get_frequency {
    freq=$(($(</sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq) / 1000))
    #freq=930
    
    if [[ -z "$thresh_warn" || -z "$thresh_crit" ]]; then
       # One or both thresholds were not specified
       echo "$PROGNAME: Threshold not set"
       print_usage
       exit $STATE_UNKNOWN
    elif [[ "$thresh_warn" -gt "$thresh_crit" ]]; then
       # The warning threshold must be greater than the critical threshold
       echo "$PROGNAME: Warning free space should be more than critical free space"
       print_usage
       exit $STATE_UNKNOWN
    fi


    # Get performance data for Shinken/Icinga or whatever you use. "Performance Data" field
    # PERFDATA=`${SENSORPROG} | grep "$sensor" | head -n1`

    if [[ "$freq" -gt "$thresh_crit" ]]; then
       # Free memory is less than the critical threshold
       echo "CRITICAL - $freq CPU frequency is to high | cpufreq=$freq;$thresh_warn;$thresh_crit;0;1200"
       exit $STATE_CRITICAL
    elif [[ "$freq" -gt "$thresh_warn" ]] && [[ "$freq" -lt "$thresh_crit" ]]; then
       # Free memory is less than the warning threshold
       echo "WARNING - CPU frequency is $freq | cpufreq=$freq;$thresh_warn;$thresh_crit;0;1200"
       exit $STATE_WARNING
    else
       # There's no error
       echo "OK - CPU frequency is $freq | cpufreq=$freq;$thresh_warn;$thresh_crit;0;1200"
       exit $STATE_OK
    fi
}

# Main #########################################################################

# Verbosity level
verbosity=0
# Warning threshold
thresh_warn=
# Critical threshold
thresh_crit=

# Parse command line options
while [ "$1" ]; do
   case "$1" in
       -h | --help)
           print_help
           exit $STATE_OK
           ;;
       -V | --version)
           print_revision
           exit $STATE_OK
           ;;
       -t | --temperature)
           get_temperature
           exit $STATE_OK
           ;;
       -f | --frequency)
           get_frequency
           exit $STATE_OK
           ;;
       -w | --warning | -c | --critical)
           if [[ -z "$2" || "$2" = -* ]]; then
               # Threshold not provided
               echo "$PROGNAME: Option '$1' requires an argument"
               print_usage
               exit $STATE_UNKNOWN
           elif [[ "$2" = +([0-9]) ]]; then
               # Threshold is a number (MB)
               thresh=$2
           else
               # Threshold is neither a number nor a percentage
               echo "$PROGNAME: Threshold must be integer or percentage"
               print_usage
               exit $STATE_UNKNOWN
           fi
           [[ "$1" = *-w* ]] && thresh_warn=$thresh || thresh_crit=$thresh
           shift 2
           ;;
       -?)
           print_usage
           exit $STATE_OK
           ;;
       *)
           echo "$PROGNAME: Invalid option '$1'"
           print_usage
           exit $STATE_UNKNOWN
           ;;
   esac
done

