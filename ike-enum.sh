#!/bin/sh

# generate list of possible transforms
if [ -f "tranforms_dict.txt" ]
then
  printf "[+] Generating list of transforms to test with later...\n"
  for ENC in 1 2 3 4 5 6 7/128 7/192 7/256 8
  do
    for HASH in 1 2 3 4 5 6
    do
      for AUTH in 1 2 3 4 5 6 7 8 64221 64222 64223 64224 65001 65002 65003 65004 65005 65006 65007 65008 65009 65010
      do
        for GROUP in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18
        do
          echo "--trans=$ENC,$HASH,$AUTH,$GROUP" >> transforms_dict.txt
        done
      done
    done
  done

else
        printf "[+] Transforms dictionary already exists, skipping...\n"
fi

# scan everything, get responses in full
printf "[+] Checking all hosts for handshakes/notify messages...\n"
while read target
do
  sudo ike-scan -M $target >> 1_handshake_test.txt
done < targets.txt

printf "[+] Parsing lists based on handshake/notify responses...\n"
# get the hosts for which we need to bruteforce valid transforms
grep -B 3 '1 returned notify' 1_handshake_test.txt | grep -E '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\s' | cut -d "N" -f 1 | tee 2_search_for_transforms.txt > /dev/null
# get the hosts for which the default ike-scan transform got a handshake
grep -B 5 '1 returned handshake' 1_handshake_test.txt | grep -E '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\s' | cut -d "M" -f 1 | tee 2_default_transforms_valid.txt > /dev/null

RANDOM_GROUP=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13 ; echo '')

printf "[+] Using the following random group ID to test Dead Peer Detection with Aggressive Mode: $RANDOM_GROUP\n"
while read grouptarget
do
  sudo ike-scan -P -M -A -n $RANDOM_GROUP $grouptarget >> 3_random_group_test_results.txt
done < 2_default_transforms_valid.txt

# pull hosts that didn't send a hash back and adding to list of hosts where valid transforms are needed
printf "[+] Adding non-DPD hosts to list of targets to bruteforce transforms for...\n"
grep -E '[0-9]*\.[0-9]*\.[0-9]*\.[0-9]*\s' 3_random_group_test_results.txt | grep -v "Aggressive" | cut -d "N" -f 1 >> 2_search_for_transforms.txt
cp 2_search_for_transforms.txt 5_transform_test_targets.txt

# create list of DPD hosts that aren't worth going after
grep 'Aggressive Mode Handshake returned' 2_default_transforms_valid.txt | cut -d "A" -f 1 | tee 4_dead_peer_detection.txt > /dev/null

printf "[!] List of targets to bruteforce transforms for stored at: 5_transform_test_targets.txt\n"
printf "[!] You can loop over them with all the entries in transforms_dict.txt\n"

# find transforms for a single IP
#while read transform
#do
        #(echo "Valid trans found: $transform" && sudo ike-scan -M $transform {IP}) | grep -B 14 "1 returned handshake" | grep "Valid trans found"
#done < transforms_dict.txt
