#!/bin/bash

# Get the target list from a text file
read -p "Enter Your Target Name: " target_domain

# Run Amass and save the results to a file
echo "Scaanning with Amass."
amass enum -passive -norecursive -noalts -d $target_domain -o amass.$target_domain.txt
echo "Amass scan completed and saved the results in amass.$target_domain.txt."

# Run Subfinder and save the results to a file
echo "Scanning with Subfinder."
subfinder -d $target_domain -o subfinder.$target_domain.txt
echo "Subfinder scan completed and saved the results in subfinder.$target_domain.txt."

# Run Sublist3r and save the results to a file
# having problem with sublist3r

# Run Assetfinder and save the results to a file
echo "Scanning with Assetfinder."
assetfinder --subs-only $target_domain > asset.$target_domain.txt
echo "Assetfinderr scan completedand saved the results in asset.$target_domain.txt."

# Combine all the results into one file
echo "Combining all the results into results.txt file."
cat $target_domain.amass.txt $target_domain.subfinder.txt $target_domain.asset.txt > results.$target_domain.txt

# Remove Previous Outputs
#rm -r amass.$target_domain.txt asset.$target_domain.txt subfinder.$target_domain.txt

# Remove Duplicates
echo "Sorting Unique results into subdomains.$target_domain.txt file."
cat results.$target_domain.txt | uniq > subdomains.$target_domain.txt

# Remove result
#rm -r results..$target_domain.txt

# Get all the URLs
#cat subdomains.$target_domain.txt | waybackurls > urls.$target_domain.txt

# Using HTTPX
echo "Getting status code using httpx and saving the results in httpx.$target_domain.txt \n"
httpx -l subdomains.$target_domain.txt -status-code -content-length -title -tech-detect -follow-redirects -o httpx.$target_domain.txt

# Find the live sites using Httprobe
cat subdomains.$target_domain.txt | httprobe > httprobe.$target_domain.txt

# DNS Enumeration Result
for domains in $(cat subdomains.$target_domain.txt);do dig $domains +noquestion +noauthority +noadditional +nostats | grep -wE "CNAME|A|NS";done > dns_result.$target_domain.txt

