devimage:
	docker build -t geoffwilliams/geoffwilliams.me.uk:dev .

run:
	docker run --rm --volume $(shell pwd):/var/www/html -P --name geoffwilliams.me.uk geoffwilliams/geoffwilliams.me.uk:dev

shell:
	docker exec -ti bash geoffwilliams.me.uk

debug:
	docker run --rm -ti --volume $(shell pwd):/var/www/html -P --name geoffwilliams.me.uk geoffwilliams/geoffwilliams.me.uk:dev bash
