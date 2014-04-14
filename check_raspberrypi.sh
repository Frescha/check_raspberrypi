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
   Exit with WARNING status if less than INTEGER MB of memory are free
-w PERCENT%
   Exit with WARNING status if less than PERCENT of memory is free
-c INTEGER
   Exit with CRITICAL status if less than INTEGER MB of memory are free
-c PERCENT%
   Exit with CRITICAL status if less than PERCENT of memory is free
-v
   Verbose output
__EOT
}

# Main #########################################################################

#temp=$(($(</sys/class/thermal/thermal_zone0/temp) / 1000))

freq=$(($(</sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq) / 1000))
#freq=630

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
       -v | --verbose)
           : $(( verbosity++ ))
           shift
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

if [[ "$verbosity" -ge 2 ]]; then
   # Print debugging information
   /bin/cat <<__EOT
Debugging information:
  Warning threshold: $thresh_warn MB
  Critical threshold: $thresh_crit MB
  Verbosity level: $verbosity
  Total memory: $tot_mem MB
  Free memory: $free_mem MB ($free_mem_perc%)
__EOT
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