-include ~/.yoker/Makefile

session-png: media/session.svg
	rsvg-convert -w 1482 media/session.svg -o media/session.png

icon-png: media/icon.svg
	rsvg-convert -w 240 media/icon.svg -o media/icon.png

serve:
	python -m http.server
