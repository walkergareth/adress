# makeSpeechTextGrids.praat - a Praat script to use Pitt corpus audio and
# transcriptions, and create TextGrid files of the recordings with three
# tiers, saving those TextGrids to ../TextGrids/:

# 1. the labels for the interviewee's speech, from the original
#  transcriptions

# 2. voice detection done in Praat, with a choice of voice activity
#  detection, or a method which looks at voiced frames in a pitch
#  trace

# 3. detection labels for just those chunks labelled in the
# transcriptions as containing speech from the interviewee

# Can be run from the command line with e.g.
# /usr/bin/praat --run makeSpeechTextGrids.praat VAD -35 0.35 1.5 0.5

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

########## FOR TESTING

testing = 0 ; 1 = on, so script only runs on one file as specified below; 0 = off (create all files)

########## FORM

form: "Set your options"
  choice: "TextGrid_type", 1
    option: "VAD"
    option: "Voicing"
  real Non_speech_threshold_(dB) -35
  real Octave_jump_cost 0.35 
  real Pitch_ceiling_factor 1.5 
  real Unvoiced_threshold_(s) 0.5
endform

# Information on arguments and default values

# Non-speech threshold
# Praat's default is -35

# Octave-jump cost
# Praat's default is 0.35

# Pitch ceiling:
# 1.5 is recommended by Hirst and De Looze for 'non-emphatic speech'
# 2.5 is recommended for 'more emphatic speech'

# Unvoiced threshold
# Portions of the signal without voiced frames need to be longer than
# this value to be considered 'silent'. Note that the threshold needs 
# to be long enough so that sequences of voiceless consonants are not 
# labelled as silences.

########## VARIABLES

#  for use in object and file names etc.

if textGrid_type = 1
  typeU$ = "VAD"
  typeL$ = "vad"
elsif textGrid_type = 2
  typeU$ = "Voiced"
  typeL$ = "voiced"
endif
typeF$ = typeU$
typeDir$ = typeU$

octaveJumpCost = octave_jump_cost
unvThreshold = unvoiced_threshold

########## TO RUN IN BATCH MODE

group$ = "cc"
@runBatch

group$ = "cd"
@runBatch

########## PROCEDURES

# set up objects
procedure setUp
  selectObject: sound
  totalDur = Get total duration
  selectObject: tg
  totalTextGridDur = Get total duration

  # find out where the tier showing the participant's speech is
  tiers = Get number of tiers
  parTier = 1
  repeat
    tierName$ = Get tier name: parTier
    parTier = parTier + 1
  until tierName$ = "PAR"
  parTier = parTier-1

  # extract the tier containing the participant's speech
  tg_paronly = Extract one tier: parTier

  selectObject: sound
endproc

# make a voice activity detection TextGrid
procedure makeTextGridVAD
  @setUp
  
  tgVAD = noprogress To TextGrid (voice activity): 0, 0.3, 0.1, 70, 6000, -10, non_speech_threshold, 0.1, 0.1, "0", "1"

  @fixBoundaries

  # clean up
  selectObject: tg_top
  plusObject: tg_paronly
  plusObject: tgVAD
  plusObject: sound
  plusObject: tg
  Remove

  selectObject: tg_merge
endproc

# make a TextGrid based on pitch detection. 
procedure makeTextGridVoicing
  # this procedure creates a pitch trace using the two-pass detection
  # method in Hirst & De Looze 2021, De Looze and Hirst 2008
  @setUp
  # pitch1 = noprogress To Pitch: 0, 60, 700
  # 'accurate' Pitch tracking
  pitch1 = noprogress To Pitch (ac): 0, 60, 15, "no", 0.03, 0.45, 0.01, octave_jump_cost, 0.14, 700
  q1 = Get quantile: 0, 0, 0.25, "Hertz"
  q3 = Get quantile: 0, 0, 0.75, "Hertz"
  pitchFloor = 0.75 * q1
  pitchCeiling = pitch_ceiling_factor * q3 
  selectObject: sound
  # pitch2 = To Pitch: 0, pitchFloor, pitchCeiling
  # 'accurate' Pitch tracking
  pitchTimeStep = 0.75 / pitchFloor ; Praat's default is (0.75 / pitchFloor)
  pitch2 = noprogress To Pitch (ac): pitchTimeStep, pitchFloor, 15, "no", 0.03,
           ...0.45, 0.01, octave_jump_cost, 0.14, pitchCeiling

  selectObject: sound
  vTextGrid = To TextGrid: "voicing", ""
  selectObject: pitch2
  frames = Get number of frames
  # place a boundary in the TextGrid where the voicing changes
  for f to frames-1
    selectObject: pitch2
    frameValue = Get value in frame: f, "Hertz"
    frameTime = Get time from frame number: f 
    nextFrameValue = Get value in frame: f+1, "Hertz"
    nextFrameTime = Get time from frame number: f+1 
    # place boundary wherever voicing changes
    if ( frameValue <> undefined and nextFrameValue = undefined )
      ...or ( frameValue = undefined and nextFrameValue <> undefined ) 
      selectObject: vTextGrid
      Insert boundary: 1, frameTime + ( ( nextFrameTime - frameTime ) / 2 ) 
      selectObject: pitch2
    endif
  endfor
  # label the intervals in the TextGrid depending on whether there is
  # a pitch value in the middle (= voicing)
  selectObject: vTextGrid
  ints = Get number of intervals: 1
  for i to ints
    intStartTime = Get start time of interval: 1, i
    intEndTime = Get end time of interval: 1, i
    selectObject: pitch2
    intMidPitch = Get value at time: intStartTime + ( ( intEndTime - intStartTime ) / 2 ), "Hertz", "linear"
    selectObject: vTextGrid
    if intMidPitch = undefined
      Set interval text: 1, i, "0"
    else
      Set interval text: 1, i, "1"
    endif
  endfor
  # make a new tier for the new labels
  Insert interval tier: 2, "voicing"
  # copy first and last intervals regardless of duration
  firstIntEndTime = Get end time of interval: 1, 1
  Insert boundary: 2, firstIntEndTime
  label$ = Get label of interval: 1, 1
  Set interval text: 2, 1, label$
  lastIntStartTime = Get start time of interval: 1, ints
  Insert boundary: 2, lastIntStartTime
  label$ = Get label of interval: 1, ints
  Set interval text: 2, 3, label$
  # cycle through all intervals from 2 to ints - 1 on tier 1
  for i from 2 to ints-1
    label$ = Get label of interval: 1, i
    if label$ = "0"
      intStartTime = Get start time of interval: 1, i
      intEndTime = Get end time of interval: 1, i
      # add boundaries on tier 2 if the interval exceeds the threshold
      if ( intEndTime - intStartTime ) > unvThreshold
        nocheck Insert boundary: 2, intStartTime
        nocheck Insert boundary: 2, intEndTime
        newTierInts = Get number of intervals: 2
        Set interval text: 2, newTierInts-2, "0"
      endif 
    endif
  endfor
  # fill in blank labels as voiced
  ints = Get number of intervals: 2
  for i to ints
    label$ = Get label of interval: 2, i
    if label$ = ""
      Set interval text: 2, i, "1"
    endif
  endfor
  Remove tier: 1

  tg_top = selected ("TextGrid")

  @fixBoundaries

  # clean up
  selectObject: tg_top
  plusObject: tg_paronly
  plusObject: vTextGrid
  plusObject: pitch1
  plusObject: pitch2
  plusObject: sound
  plusObject: tg
  Remove

  selectObject: tg_merge
endproc

# work on the boundaries in the new tiers
procedure fixBoundaries
  # extract the top tier
  tg_top = Extract one tier: 1
  Set tier name: 1, typeF$
  # merge that tier with the tier containing the participant's speech
  plusObject: tg_paronly
  tg_merge = Merge
  Rename: file$ + "-" + typeL$
  # make a new tier for voice detection for labelled portions
  Insert interval tier: 3, "PAR-" + typeU$

  selectObject: tg_merge

  # go through each interval on tier 2...
  intsN = Get number of intervals: 2
  for i to intsN
    # ...get the middle of the interval... 
    iStart = Get start time of interval: 2, i
    iEnd = Get end time of interval: 2, i
    iMid = iStart+((iEnd-iStart)/2)

    if iMid <= totalDur and iMid <= totalTextGridDur
      # ...and get the label of the interval at that time on tier 1...
      iNum = Get interval at time: 1, iMid
      iLab$ = Get label of interval: 1, iNum
      # ...and add boundaries if that label is non-empty
      if iLab$ <> ""
        nocheck Insert boundary: 3, iStart
        nocheck Insert boundary: 3, iEnd
      endif
    endif
  endfor

  # go through each interval on tier 1...
  intsN = Get number of intervals: 1
  for i to intsN
    lab$ = Get label of interval: 1, i
    # if the label is non-empty then add boundaries on tier 3
    if lab$ <> ""
      iStart = Get start time of interval: 1, i
      iEnd = Get end time of interval: 1, i
      nocheck Insert boundary: 3, iStart
      nocheck Insert boundary: 3, iEnd
    endif
  endfor

  # go through each interval on tier 3...
  intsN = Get number of intervals: 3
  for i to intsN
    # ...and get the midpoint of the interval...
    iStart = Get start time of interval: 3, i
    iEnd = Get end time of interval: 3, i
    iDur = iEnd-iStart
    iMid = iStart+((iDur)/2)
    # ...then get the label of the interval at that time on tier 1...
    if iMid <= totalDur and iMid <= totalTextGridDur
      iInt = Get interval at time: 1, iMid
      iLab$ = Get label of interval: 1, iInt
      # and if that label is non-empty, copy the label from tier 2
      if iLab$ <> "" 
        iInt = Get interval at time: 2, iMid
        iLab$ = Get label of interval: 2, iInt
        Set interval text: 3, i, iLab$
      endif
    endif
  endfor
  
  # in VAD mode, get rid of intervals with a sounding label where these
  # have a duration of less than 0.4 s and a non-sounding interval
  # on both sides
  if textGrid_type = 1
      intsN = Get number of intervals: 3
      for i from 2 to intsN-1
        lab$ = Get label of interval: 3, i
        labPre$ = Get label of interval: 3, i-1
        labPost$ = Get label of interval: 3, i+1
        if lab$ = "1"
          labStart = Get start time of interval: 3, i
          labEnd = Get end time of interval: 3, i
          labDur = labEnd-labStart
          if labDur < 0.4 and ( labPre$ <> "1" and labPost$ <> "1" )
            Set interval text: 3, i, "0"
          endif
        endif
      endfor
  endif

  # copy boundaries where there are different labels on each side of a boundary
  # (so that there are no boundaries between adjacent intervals with the same label)
  Insert interval tier: 4, "PAR-" + typeU$
  intsN = Get number of intervals: 3
  for i to intsN-1
    labFirst$ = Get label of interval: 3, i
    labSecond$ = Get label of interval: 3, i+1
    if labFirst$ <> labSecond$
      iEnd = Get end time of interval: 3, i
      nocheck Insert boundary: 4, iEnd
    endif
  endfor
  
  # re-label tier 4; go through each interval on tier 4...
  intsN = Get number of intervals: 4
  for i to intsN
    # ...and get the midpoint of the interval...
    iStart = Get start time of interval: 4, i
    iEnd = Get end time of interval: 4, i
    iMid = iStart+((iEnd-iStart)/2)
    # ...then get the label of the interval at that time on tier 3...
    iInt = Get interval at time: 3, iMid
    iLab$ = Get label of interval: 3, iInt
    # and if that label is non-empty, copy the label from tier 3
    if iLab$ <> ""
      Set interval text: 4, i, iLab$
    endif
  endfor

  # remove tier 3
  Remove tier: 3
  
endproc

# run in batch mode (run on all files)

procedure runBatch
  folder$ = "../ADReSS-IS2020-data/combined/Full_wave_enhanced_audio/" + group$ + "/"
  strings = Create Strings as file list: "list", folder$ + "*.wav"
  if testing = 1
    numberOfFiles = 1
  elsif testing = 0
    numberOfFiles = Get number of strings
  endif
  for ifile to numberOfFiles
    selectObject: strings
    fileName$ = Get string: ifile
    file$ = replace$ (fileName$, ".wav", "", 0)
    sound = Read from file: folder$ + file$ + ".wav"
    tg = Read from file: folder$ + "../../transcription/" + group$ + "/" + file$ + ".TextGrid"
    if textGrid_type = 1
      @makeTextGridVAD
    elsif textGrid_type = 2
      @makeTextGridVoicing
    endif
    # make the folders as required
    createFolder ("../ADReSS-IS2020-data/combined/TextGrids/")
    createFolder ("../ADReSS-IS2020-data/combined/TextGrids/" + typeDir$)
    createFolder ("../ADReSS-IS2020-data/combined/TextGrids/" + typeDir$ + "/" + group$)
    Save as text file: "../ADReSS-IS2020-data/combined/TextGrids/" + typeDir$ + "/" + group$ + "/" + file$ + "-" + typeF$ + ".TextGrid"
    #Remove
  endfor
  selectObject: strings
  Remove
endproc
