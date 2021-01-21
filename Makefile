build:
	hugo -D

clean:
	rm -rf ./public

deploy:
	rsync -uvrP --delete-after ./public/ root@hkva.net:/var/www/hkva/

serve:
	python3 -m http.server -d ./public/
