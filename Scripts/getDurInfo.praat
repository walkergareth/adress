# getDurInfo.praat - a Praat script to get duration info from ADReSS
#  TextGrids: see the script makeSpeechTextGrids.praat

# Copyright (C) 2024 Gareth Walker.

# g.walker@sheffield.ac.uk
# School of English
# University of Sheffield
# Jessop West
# 1 Upper Hanover Street
# Sheffield
# S3 7RA

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see
# <http://www.gnu.org/licenses/>.

form: "Read file"
  infile: "file", ""
endform

# sample file
# ../ADReSS-IS2020-data/combined/TextGrids/Union/cc/S001-Union.TextGrid 

tg = Read from file: file$

# always examine the tier at the bottom
tiers = Get number of tiers

ansDur=undefined
spDur=undefined
silPauseDur=undefined
silPauseCount=undefined
silPauseAve=undefined
silPauseProp=undefined

########### check the number of intervals labelled "1"

intNum = Get number of intervals: tiers
labCheck = 0
for i to intNum
  labCheck$ = Get label of interval: tiers, i
  if labCheck$ = "1"
    labCheck = labCheck + 1
  endif
endfor

if labCheck > 0

    # get the start of the first interval labelled "1"
    int = 1
    repeat
      lab$ = Get label of interval: tiers, int
      int = int+1
    until lab$ = "1"
    start_int = int-1
    ansStart = Get start time of interval: tiers, start_int

    # get the end of the last interval labelled "1"
    int = Get number of intervals: tiers
    repeat
      lab$ = Get label of interval: tiers, int
      int = int-1
    until lab$ = "1"
    end_int = int+1
    ansEnd = Get end time of interval: tiers, end_int

    ########### get spDur and silPauseDur

    # spDur, silPauseDur and silPauseCount only include intervals
    # labelled "0" between the first interval labelled "1" and the
    # last interval labelled "1" (any initial and final intervals
    # labelled "0" are ignored).
    
    ints = Get number of intervals: tiers
    spDur = 0
    silPauseDur = 0
    silPauseCount = 0
    for i from start_int to end_int
      lab$ = Get label of interval: tiers, i
      intStart = Get start time of interval: tiers, i
      intEnd = Get end time of interval: tiers, i
      intDur = intEnd - intStart
      if lab$ = "1"
        spDur = spDur + intDur
      elsif lab$ = "0"
        silPauseDur = silPauseDur + intDur
        silPauseCount = silPauseCount + 1
      endif
    endfor

    ########### get ansDur

    # this combines the measures of silent pauses and speech in
    # portions of the recording attributed in the transcription to the
    # interviewee, between the first and last intervals labelled "1"
    # (any initial and final intervals labelled "0" are ignored). This
    # gives an approximation of the total duration of the answer.

    ansDur = spDur+silPauseDur

    ########### get silPauseAve

    silPauseAve = silPauseDur/silPauseCount

    ########### get silPauseProp

    # silPauseProp is the proportion of the sample labelled as
    # belonging to the interviewee that is taken up by silence,
    # between the first interval labelled "1" and the last interval
    # labelled "1" (any initial and final intervals labelled "0" are
    # ignored)
    
    silPauseProp = (silPauseDur/ansDur)*100

endif

appendInfoLine: file$, ",", spDur, ",", silPauseDur, ",", ansDur, ",", silPauseCount, ",", silPauseAve,",",
...silPauseProp
