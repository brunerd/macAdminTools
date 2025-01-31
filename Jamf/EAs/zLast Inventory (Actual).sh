#!/bin/bash
# zLast Inventory (Actual) -  Copyright (c) 2025 Joel Bruner (https://github.com/brunerd/macAdminTools/tree/main/Jamf/EAs) Licensed under the MIT License
# A Jamf Pro Extension Attribute to report the _actual time_ of a successful inventory submission
# This is to address two issues with the built-in Last Inventory:
#  1) This date stamp is not affected by API writes to the computer record
#  2) Detect "Unknown Error" inventory submission failures if date does not match built-in this indicates failure

# Notes:
# The "z" at the beginning of the EA name is to ensure it is run last and is closest to built-in Last Inventory datestamp
# EA date types do not consider offsets so we must normalize the time to UTC (-u) for the most consistent behavior
# When viewing the date in Reports, Inventory Display, or Computer Records it will not be localized like built-in

#ISO 8601(-ish) date format with UTC/GMT normalized time (YYYY-MM-DD HH:MM:SS)
DATE_NORMALIZED=$(date -u +"%F %T")

echo "<result>${DATE_NORMALIZED}</result>"
