Index and search browser bookmarks from the command line.

Currently only works with Firefox bookmarks.

Install:

	pip install -e git+https://github.com/chr15m/marcus.git#egg=marcus

(hint: use `--user` to install into `~/.local/bin/`)

Index your bookmarks. The first time you run this it will take a while, depending on how many bookmarks you have.

	$ marcus --index
	Start 2017-01-12 21:20
	Indexing 10 / 1081 bookmarks
	...

Now run a search.

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

Patches welcome. Enjoy!
