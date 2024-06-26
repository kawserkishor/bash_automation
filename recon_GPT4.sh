#!/bin/bash
# A simple bash script to automate the recon process of bug bounty

# Variable declaration
dns_wordlist="/usr/share/wordlists/seclists/Discovery/DNS/sortedcombined-knock-dnsrecon-fierce-reconng.txt"
resolver="/usr/share/wordlists/dns-resolvers/resolvers.txt"
commonPorts="/usr/share/wordlists/commonPorts.txt"

# Check if a domain is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: ./recon.sh domain.com"
  exit 1
fi

# Set the domain variable
domain=$1

# Create a directory for the domain
mkdir -p $domain

# Perform subdomain enumeration using Subfinder, Assetfinder, and Amass
echo "[+] Enumerating subdomains for $domain"
subfinder -d $domain | tee -a $domain/subdomains.txt
assetfinder --subs-only $domain | tee -a $domain/subdomains.txt
amass enum -passive -norecursive -noalts -d $domain | tee -a $domain/subdomains.txt

# Perform subdomain enumeration from crt.sh
crtsh -d $domain | tee -a $domain/subdomains.txt

# Brute forcing subdomain enumeration using Puredns
puredns bruteforce $dns_wordlist $domain --resolvers $resolver | tee -a $domain/subdomains.txt

# Sort and remove duplicate subdomains
echo "[+] Sorting and removing duplicate subdomains"
sort -u $domain/subdomains.txt -o $domain/subdomains.txt

# Check for live subdomains using httprobe
echo "[+] Checking for live subdomains"
cat $domain/subdomains.txt | httprobe | tee -a $domain/live_subdomains.txt

# Take screenshots of live subdomains using Aquatone
echo "[+] Taking screenshots of live subdomains"
cat $domain/live_subdomains.txt | aquatone -out $domain/aquatone

# Perform port scanning using Naabu
echo "[+] Performing port scanning"
naabu -iL $domain/live_subdomains.txt -p $commonPorts -o $domain/naabu.txt

# Perform directory brute-forcing using Gobuster
echo "[+] Performing directory brute-forcing"
while read url; do
  gobuster dir -u $url -w /usr/share/wordlists/dirb/common.txt -q -o $domain/gobuster/$(echo $url | cut -d/ -f3).txt
done < $domain/live_subdomains.txt

# Perform content discovery using FFUF
echo "[+] Performing content discovery"
while read url; do
  ffuf -u $url/FUZZ -w /usr/share/wordlists/dirb/common.txt -mc 200,301,302,307,403 -o $domain/ffuf/$(echo $url | cut -d/ -f3).json
done < $domain/live_subdomains.txt

# Perform parameter discovery using Arjun
echo "[+] Performing parameter discovery"
while read url; do
  arjun -u $url --get --post --json --output $domain/arjun/$(echo $url | cut -d/ -f3).json
done < $domain/live_subdomains.txt

# Perform XSS scanning using Dalfox
echo "[+] Performing XSS scanning"
while read url; do
  dalfox url $url --silence --output $domain/dalfox/$(echo $url | cut -d/ -f3).txt
done < $domain/live_subdomains.txt

# Perform SQLi scanning using SQLmap
echo "[+] Performing SQLi scanning"
while read url; do
  sqlmap -u "$url" --batch --crawl=10 --level=5 --risk=3 --output-dir=$domain/sqlmap/
done < $domain/live_subdomains.txt

# Perform CORS scanning using CORScanner
echo "[+] Performing CORS scanning"
corscanner -i $domain/live_subdomains.txt -t 50 -o $domain/corscanner.csv

# Perform subdomain takeover scanning using Subjack and Subzy
echo "[+] Performing subdomain takeover scanning"
subjack -w $domain/subdomains.txt -t 50 -timeout 30 -ssl -c ~/go/src/github.com/haccer/subjack/fingerprints.json -v 3 -o $domain/subjack.txt
subzy -targets $domain/subdomains.txt --hide_fails --verify_ssl --concurrency 50 --output $domain/subzy.json

# Perform vulnerability scanning using Nuclei
echo "[+] Performing vulnerability scanning"
nuclei -l $domain/live_subdomains.txt -t ~/nuclei-templates/ -c 50 -o $domain/nuclei.txt

# Perform secret scanning using Gitleaks
echo "[+] Performing secret scanning"
gitleaks --repo-path=$domain/aquatone/screenshots/ --report=$domain/gitleaks.json --verbose --redact

# Perform SSL/TLS analysis using Testssl.sh
echo "[+] Performing SSL/TLS analysis"
testssl --file=$domain/live_subdomains.txt --quiet --color 0 >$domain/testssl.txt

# Perform DNS analysis using DIG
echo "[+] Performing DNS analysis"
for sub in $(cat $domain/live_subdomains.txt); do dig $sub +noquestion +noauthority +noadditional +nostats | grep -wE "CNAME|A"; done > $domain/dig.txt

# Perform OSINT using theHarvester
echo "[+] Performing OSINT"
theHarvester -d $domain -b all -f $domain/theHarvester.html

# Perform social media analysis using Sherlock
echo "[+] Performing social media analysis"
sherlock $domain --output $domain/sherlock/

# Perform web archive analysis using Waybackurls and Gau
echo "[+] Performing web archive analysis"
cat $domain/subdomains.txt | waybackurls | tee -a $domain/waybackurls.txt
cat $domain/subdomains.txt | gau | tee -a $domain/gau.txt

# Perform JavaScript analysis using LinkFinder and SecretFinder
echo "[+] Performing JavaScript analysis"
while read url; do
  linkfinder -i $url -o cli | tee -a $domain/linkfinder.txt
  secretfinder -i $url -o cli | tee -a $domain/secretfinder.txt
done < $domain/gau.txt

# Perform wordlist generation using CeWL and SecLists
echo "[+] Performing wordlist generation"
cewl -d 2 -m 5 -w $domain/cewl.txt https://$domain
cat /usr/share/seclists/Discovery/Web-Content/* | sort -u >$domain/seclists.txt

# Perform report generation using Markdown
echo "[+] Performing report generation"
echo "# Recon Report for $domain" >$domain/report.md
echo "## Subdomains" >>$domain/report.md
cat $domain/subdomains.txt >>$domain/report.md
echo "## Live Subdomains" >>$domain/report.md
cat $domain/live_subdomains.txt >>$domain/report.md
echo "## Screenshots" >>$domain/report.md
ls $domain/aquatone/*.png | sed 's/^/![](/;s/$/)/' >>$domain/report.md
echo "## Port Scanning" >>$domain/report.md
cat $domain/naabu.txt >>$domain/report.md
echo "## Directory Brute-Forcing" >>$domain/report.md
ls $domain/gobuster/*.txt | xargs -I{} sh -c 'echo "### {}"; cat {}' >>$domain/report.md
echo "## Content Discovery" >>$domain/report.md
ls $domain/ffuf/*.json | xargs -I{} sh -c 'echo "### {}"; cat {}' >>$domain/report.md
echo "## Parameter Discovery" >>$domain/report.md
ls $domain/arjun/*.json | xargs -I{} sh -c 'echo "### {}"; cat {}' >>$domain/report.md
echo "## XSS Scanning" >>$domain/report.md
ls $domain/dalfox/*.txt | xargs -I{} sh -c 'echo "### {}"; cat {}' >>$domain/report.md
echo "## SQLi Scanning" >>$domain/report.md
ls $domain/sqlmap/*/*.log | xargs -I{} sh -c 'echo "### {}"; cat {}' >>$domain/report.md
echo "## CORS Scanning" >>$domain/report.md
cat $domain/corscanner.csv >>$domain/report.md
echo "## Subdomain Takeover Scanning" >>$domain/report.md
cat $domain/subjack.txt >>$domain/report.md
cat $domain/subzy.json >>$domain/report.md
echo "## Vulnerability Scanning" >>$domain/report.md
cat $domain/nuclei.txt >>$domain/report.md
echo "## Secret Scanning" >>$domain/report.md
cat $domain/gitleaks.json >>$domain/report.md
echo "## SSL/TLS Analysis" >>$domain/report.md 
cat $domain/testssl.txt >>$domain/report.md 
echo "## DNS Analysis" >>$domain/report.md 
cat $domain/dig.txt >>$domain/report.md
echo "## OSINT" >>$domain/report.md 
cat $domain/theHarvester.html >>$domain/report.md 
echo "## Social Media Analysis" >>$domain/report.md 
ls $domain/sherlock/*.txt | xargs -I{} sh -c 'echo "### {}"; cat {}' >>$domain/report.md

echo "Report generation completed. Find the report at ./$domain/report.md"
