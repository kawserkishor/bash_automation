#!/bin/bash

# Get the target list from a text file
read -p "Enter Your Target Name: " target_domain

# Run Amass and save the results to a file
echo -e "Scaanning with Amass. \n"
amass enum -passive -norecursive -noalts -d $target_domain -o amass.$target_domain.txt
echo -e "Amass scan completed and saved the results in amass.$target_domain.txt. \n"

# Run Subfinder and save the results to a file
echo -e "Scanning with Subfinder. \n"
subfinder -d $target_domain -o subfinder.$target_domain.txt
echo -e "Subfinder scan completed and saved the results in subfinder.$target_domain.txt. \n"

# Run Sublist3r and save the results to a file
# having problem with sublist3r

# Run Assetfinder and save the results to a file
echo -e "Scanning with Assetfinder. \n"
assetfinder --subs-only $target_domain > asset.$target_domain.txt
echo -e "Assetfinderr scan completedand saved the results in asset.$target_domain.txt. \n"

# Combine all the results into one file
echo -e "Combining all the results into results.txt file. \n"
cat $target_domain.amass.txt $target_domain.subfinder.txt $target_domain.asset.txt > results.$target_domain.txt

# Remove Previous Outputs
#rm -r amass.$target_domain.txt asset.$target_domain.txt subfinder.$target_domain.txt

# Remove Duplicates
echo -e "Sorting Unique results into subdomains.$target_domain.txt file. \n"
cat results.$target_domain.txt | uniq > subdomains.$target_domain.txt

# Remove result
#rm -r results..$target_domain.txt

# Get all the URLs
#cat subdomains.$target_domain.txt | waybackurls > urls.$target_domain.txt

# Using HTTPX
echo -e "Getting status code using httpx and saving the results in httpx.$target_domain.txt \n"
httpx -l subdomains.$target_domain.txt -status-code -content-length -title -tech-detect -follow-redirects -o httpx.$target_domain.txt

# Find the live sites using Httprobe
cat subdomains.$target_domain.txt | httprobe > httprobe.$target_domain.txt

# DNS Enumeration Result
for domains in $(cat subdomains.$target_domain.txt);do dig $domains +noquestion +noauthority +noadditional +nostats | grep -wE "CNAME|A|NS";done > dns_result.$target_domain.txt

