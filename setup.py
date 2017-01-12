#!/usr/bin/env python

from distutils.core import setup

setup(name='marcus',
      version='0.1',
      description='Index and search bookmarks from the command line.',
      author='Chris McCormick',
      author_email='chris@mccormick.cx',
      url='http://github.com/chr15m/marcus',
      packages=['marcus'],
      package_data = {
          'marcus' : ['*.hy'],
      },
      #dependency_links=[
      #    'https://github.com/chr15m/...',
      #],
      install_requires=[
          'hy==0.11.1',
          'Whoosh==2.7.4',
          'html2text==2016.9.19',
          'newspaper==0.0.9.8',
          'colorama==0.3.7',
          'pyasn1==0.1.9',
          'ndg_httpsclient==0.4.2',
      ],
      scripts=['bin/marcus']
)
