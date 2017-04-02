Index and search browser bookmarks from the command line.

Works with Chrome and Firefox.

	$ marcus "quantum cryptography"
	found 9

	1. 	Quantum cryptography - Wikipedia
		https://en.wikipedia.org/wiki/Quantum_cryptography
		Added: 2017-03-21
		> ...known example of **quantum** **cryptography** is **quantum** key...
		> ...distribution...application of **quantum** **cryptography** is **quantum** key...
		> ...distribution...32] Post-**quantum** **cryptography** [ edit ] **Quantum**...
		> ...computers may become...
	...

### Install

	pip install marcus

(hint: use `--user` to install into `~/.local/bin/`)

Then run `marcus` (or `~/.local/bin/marcus`) with no arguments to get help.

### Index your bookmarks

The first time you run this it will take a while, depending on how many bookmarks you have.

	$ marcus --index ~/.config/chromium/Default/Bookmarks
	Start 2017-01-12 21:20
	Indexing 10 / 1081 bookmarks
	Indexing https://www.mozilla.org/en-US/firefox/central/ (0 / 1081) 0% done
	Indexing http://www.ubuntu.com/ (1 / 1081) 0% done
	...

To find a list of bookmark files belonging to the current user:

	$ marcus --find-bookmark-files

Firefox on Linux example:

	$ marcus --index ~/.mozilla/firefox/*.default/places.sqlite

### Full-text bookmark search

	$ marcus privacy
	found 84
	
	1. 	Privacy and control need to be put back into the hands of the individual – Decentralize Today
		https://decentralize.today/privacy-and-control-need-to-be-put-back-into-the-hands-of-the-individual-301c4c318ef8#.9uk0e4ysu
		Added: 2016-09-05
		> ...a worldwide problem. **Privacy** and control need...which will bring...
		> ...**privacy**, money and communication...be blended into one **privacy**...
		> ...ecosystem. The pinnacle...
	
	2. 	How ‘strong anonymity’ will finally fix the privacy problem
		http://venturebeat.com/2016/10/08/how-strong-anonymity-will-finally-fix-the-privacy-problem/
		Added: 2016-10-09
		> ...You have zero **privacy** anyway. Get over...to protect their **privacy** in...
		> ...an online world...
	
	3. 	Germany planning to ′massively′ limit privacy rights | Germany | DW.COM | 25.11.2016
		http://m.dw.com/en/germany-planning-to-massively-limit-privacy-rights/a-36529692
		Added: 2016-12-02
		> ...major limitation of **privacy** rights in Germany...massive" erosion of...
		> ...**privacy** in Germany. De Maiziere...authorities, say **privacy** groups "The...
		> ...limitation...
	
	...

You can also use [more complex queries](https://whoosh.readthedocs.io/en/latest/querylang.html) like `privacy AND github.com` for example.

### Automated indexing

Edit your user's crontab with `crontab -e` and then add a line at the bottom like this:

	17 * * * * $PATH-TO-BINARY/marcus --index ~/.config/chromium/Default/Bookmarks >> $HOME/.marcus.log 2>&1

Which will run the indexer every hour at 17 minutes past the hour. Pages which have already been indexed will not be indexed again.

Patches welcome. Enjoy!
