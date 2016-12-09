#!/bin/bash

# ############################################################
# Set the following input parameters:

# make sure to end with a "/"
lepMap2Bin="/home/benrancourt/Desktop/LepMAP2/binary/bin/"

# 1==do the Filtering module, 0==skip the Filtering module
doFiltering=0

# make sure to end with a "/"
dataLocationWithFinalSlash="/home/benrancourt/Downloads/test/"

inputFileNameMainPart="R28-S91-M28K-Ben"
inputFileNameDotSuffix=".linkage"

sizeLimitSeparateChr=10
lodLimitSeparateChr=10
lodLimitJoinSingles=6


# End of input parameters.
# ############################################################











# ############################################################
# These parameters don't need to be edited from use to use:

logFileNameSuffix="-lepMAP2-log.txt"

# output file naming conventions
filteredOutputSuffix="-filtered.linkage"

mainInputFileSuffix=$inputFileNameDotSuffix
separateChromosomesOutputSuffix="-map.txt"
joinSinglesOutputSuffix="-map_js.txt"

orderMarkersOutputSuffixPt1="-map_js-chr"
orderMarkersOutputSuffixPt2=".SA.txt"
orderMarkersLogFileNameSuffixPt1="-orderMarkers-chr"
orderMarkersLogFileNameSuffixPt2="-lepMAP2-log.txt"

if [[ $doFiltering -eq 1 ]]
then
  mainInputFileSuffix=$filteredOutputSuffix
  separateChromosomesOutputSuffix="-filtered-map.txt"
  joinSinglesOutputSuffix="-filtered-map_js.txt"

  orderMarkersOutputSuffixPt1="-filtered-map_js-chr"
  orderMarkersLogFileNameSuffixPt1="-filtered-orderMarkers-chr"
fi

dl=$dataLocationWithFinalSlash

mainLog=$dl$inputFileNameMainPart$logFileNameSuffix


# ############################################################
# build the commands using above parameters

#default dataTolerance is 0.01
filterCommand="java -cp "$lepMap2Bin" Filtering data="$dl$inputFileNameMainPart$inputFileNameDotSuffix

separateChromosomesCommand="java -cp "$lepMap2Bin" SeparateChromosomes data="$dl$inputFileNameMainPart$mainInputFileSuffix" lodLimit="$lodLimitSeparateChr" sizeLimit="$sizeLimitSeparateChr

joinSinglesCommand="java -cp "$lepMap2Bin" JoinSingles "$dl$inputFileNameMainPart$separateChromosomesOutputSuffix" data="$dl$inputFileNameMainPart$mainInputFileSuffix" lodLimit="$lodLimitJoinSingles

orderMarkersCommandChooseLG="java -cp "$lepMap2Bin" OrderMarkers data="$dl$inputFileNameMainPart$mainInputFileSuffix" map="$dl$inputFileNameMainPart$joinSinglesOutputSuffix" alpha=0.1 polishWindow=100 filterWindow=10  sexAveraged=1 chromosome="

#-----


# ############################################################
function printMainLogFileDivider {
  echo " " | tee -a $mainLog  
  echo "===========================================================================" >> $mainLog
  echo "===========================================================================" >> $mainLog
  date | tee -a $mainLog
}


# ############################################################
function getNumLinkageGroups {
  # parameter $1 should be the name the map file we will be checking to determin number of linkage groups

  # number of linkage groups = the number of unique lines (minus the header) in the file
  numLinkageGroups=`sort -u $dl$1 | wc -l` 
  numLinkageGroups=$((numLinkageGroups-1)) # - 1 because of the header line
}


# ############################################################
function countMarkersInLinkageGroups {
  ### Count the number of markers in each Linkage Group

  mapFileName=$1 # $1 retrieves the first input parameter to this function

  printMainLogFileDivider
  getNumLinkageGroups $mapFileName

  echo "Number of Linkage Groups in "$mapFileName": "$numLinkageGroups" (might be only "$((numLinkageGroups-1))" if some markers are in 0=no linkage group)" | tee -a $mainLog  

  for i in `seq 0 $numLinkageGroups`
  do 
    count=`grep -c "^$i$" $dataLocationWithFinalSlash$mapFileName`
    echo "Number of markers in LG "$i": "$count | tee -a $mainLog  
  done

}



# ############################################################
# execute the commands:
 
echo "Beginning processing $inputFileNameMainPart$inputFileNameDotSuffix with LepMAP2 modules." | tee $mainLog
echo " " >> $mainLog

### Filtering 
if [[ $doFiltering -eq 1 ]]
then
  printMainLogFileDivider  
  echo "Beginning LepMAP2 Filtering module. Output filename: $inputFileNameMainPart$filteredOutputSuffix." | tee -a $mainLog
  echo " " >> $mainLog

  $filterCommand > $dl$inputFileNameMainPart$filteredOutputSuffix 2>> $mainLog
else
  echo " " | tee -a $mainLog
  echo "doFiltering==0, therefore skipping LepMAP2 Filtering module." | tee -a $mainLog
fi

### SeparateChromosomes
printMainLogFileDivider  
echo "Beginning LepMAP2 SeparateChromosomes module. Output filename: $inputFileNameMainPart$separateChromosomesOutputSuffix." | tee -a $mainLog
echo " " >> $mainLog

$separateChromosomesCommand > $dl$inputFileNameMainPart$separateChromosomesOutputSuffix 2>> $mainLog

### Count the number of markers in each Linkage Group in the SeparateChromosomes map file
countMarkersInLinkageGroups $inputFileNameMainPart$separateChromosomesOutputSuffix

### JoinSingles
printMainLogFileDivider  
echo "Beginning LepMAP2 JoinSingles module. Output filename: $inputFileNameMainPart$joinSinglesOutputSuffix." | tee -a $mainLog
echo " " >> $mainLog

$joinSinglesCommand > $dl$inputFileNameMainPart$joinSinglesOutputSuffix 2>> $mainLog

### Count the number of markers in each Linkage Group after JoinSingles
countMarkersInLinkageGroups $inputFileNameMainPart$joinSinglesOutputSuffix


### =========================================
### OrderMarkers SA for each linkage group, in parallel:

printMainLogFileDivider  
echo "Beginning LepMAP2 OrderMarkers SA modules. See individual Order Markers log files for each Linkage Group." | tee -a $mainLog

getNumLinkageGroups $inputFileNameMainPart$joinSinglesOutputSuffix
counter=0
ncore="$(( ($(grep -c ^processor /proc/cpuinfo) -4) ))"

echo "running parallel processing"

for i in `seq 1 $numLinkageGroups`
do
  if [ $counter -ge $ncore ]; then
    wait
    #echo "wait reset"
    counter=0
  fi 

  date > $dl$inputFileNameMainPart$orderMarkersLogFileNameSuffixPt1$i$orderMarkersLogFileNameSuffixPt2
  echo "Beginning LepMAP2 OrderMarkers SA module. Output filename: $dl$inputFileNameMainPart$orderMarkersOutputSuffixPt1$i$orderMarkersOutputSuffixPt2." | tee -a $dl$inputFileNameMainPart$orderMarkersLogFileNameSuffixPt1$i$orderMarkersLogFileNameSuffixPt2
  echo " " >> $dl$inputFileNameMainPart$orderMarkersLogFileNameSuffixPt1$i$orderMarkersLogFileNameSuffixPt2

  $orderMarkersCommandChooseLG$i > $dl$inputFileNameMainPart$orderMarkersOutputSuffixPt1$i$orderMarkersOutputSuffixPt2 2>> $dl$inputFileNameMainPart$orderMarkersLogFileNameSuffixPt1$i$orderMarkersLogFileNameSuffixPt2 &
  counter=$(( $counter + 1 ))
done
wait

### =========================================



### Done
printMainLogFileDivider

echo "Finished processing." | tee -a $mainLog

echo  -e "\033[33;5;7mPipeline $name has finished\033[0m"


 

