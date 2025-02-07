#!/bin/bash
# zLast Inventory (Actual) -  Copyright (c) 2025 Joel Bruner (https://github.com/brunerd/macAdminTools/tree/main/Jamf/EAs) Licensed under the MIT License
# A Jamf Pro Extension Attribute to report the _actual time_ of a successful inventory submission
# This is to address two issues with the built-in Last Inventory:
#  1) This date stamp is not affected by API writes to the computer record
#  2) Detect "Unknown Error" inventory submission failures if date does not match built-in Last Inventory date (excluding API writes in History)

# Notes:
# The "z" at the beginning of this EA's name is to ensure it is runs last and is closest to built-in Last Inventory datestamp
# The Jamf EA date type does not consider time zone offsets so we must normalize the time to UTC (-u) for the most consistent behavior
# When viewing an EA date in a Report, Inventory Display, or Computer Record it will not be localized according to Preferences as built-in dates are

#MySQL DATETIME format with time normalized to UTC (YYYY-MM-DD HH:MM:SS)
DATE_NORMALIZED=$(date -u +"%F %T")

echo "<result>${DATE_NORMALIZED}</result>"
