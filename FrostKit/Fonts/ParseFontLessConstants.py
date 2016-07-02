#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''
  ParseFontLessConstants.py
  FrostKit
  
  Created by James Barrow on 06/02/2015.
  Copyright (c) 2015 Frostlight Solutions. All rights reserved.
  
  This script takes in a list of less file names that refer to files in the LessConstantsFiles
  directory. This script then loops though thouse files and converts them into a single Swift
  file that contains all the public constants for every icon font included.
  
  This script is run from the FontConstantsBuilder target.
'''

import datetime, sys

def todaysFormattedDate():
  today = datetime.datetime.now()
  return today.strftime('%d/%m/%Y %H:%M:%S')

def parseFontConsatnts(inputPath, outputPath):
  name = inputPath.split('.')[0]
  contents = ''
  contents += '\n/*\n------------------------------\n'
  contents += name
  contents += '\n------------------------------\n*/\n\n'
  contents += 'public struct ' + name + ' {\n'

  openObject = open('LessConstantsFiles/' + inputPath)
  openFile = openObject.read()
  
  for line in openFile.splitlines():
    if 'var' in line:
      line = line.split('-var-')[1]
      line = line.replace('-', '_')
      line = line.replace(' ', '')
      line = line.replace('\"', '')
      line = line.replace('\\', '')
      line = line.replace(';', '')

      components = line.split(':')
      
      sub_components = components[0].split('_')
      for index in range(len(sub_components)):
        if index > 0:
          word = sub_components[index]
          sub_components[index] = word.capitalize()
      components[0] = ''.join(sub_components)

      # Fix Pre-Swift 2.2 phrases
      if components[0] in ['repeat', 'subscript', 'try']:
        components[0] = components[0] + "_"

      if components[0][0] in ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9']:
        components[0] = "_" + components[0]

      swiftLine = '\tpublic static let ' + components[0] +' = \"\\u{' + components[1] + '}\"\n'

      contents += swiftLine

  contents += '}\n'

  return contents

def parseFonts(fonts):
  outputPath = 'FontConstants.swift'
  contents = """//
//  FontConstants.swift
//  FrostKit
//
//  Created by James Barrow on 06/02/2015.
//  Copyright © 2014-Current James Barrow - Frostlight Solutions. All rights reserved.
//  Last updated on %s.
//
""" %(todaysFormattedDate())
  
  contents += '\n// swiftlint:disable variable_name\n// swiftlint:disable type_body_length\n// swiftlint:disable file_length\n'
  
  for font in fonts:
    contents += parseFontConsatnts(font, outputPath)

  contents += '\n// swiftlint:enable variable_name\n// swiftlint:enable type_body_length\n// swiftlint:enable file_length\n'

  writeObject = open(outputPath, 'wb')
  writeObject.write(contents)

def main():
  fileNames = sys.argv[1].split(' ')
  parseFonts(fileNames)

if __name__ == "__main__":
  main()
