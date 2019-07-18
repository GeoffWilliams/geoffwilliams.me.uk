devimage:
	docker build -t geoffwilliams/geoffwilliams.me.uk:dev .

run:
	docker run --rm --volume $(shell pwd):/var/www/html -P --name geoffwilliams.me.uk geoffwilliams/geoffwilliams.me.uk:dev

shell:
	docker exec -ti geoffwilliams.me.uk bash

shellonly:
	docker run --rm --volume $(shell pwd):/var/www/html -ti geoffwilliams/geoffwilliams.me.uk:dev bash

debug:
	docker run --rm -ti --volume $(shell pwd):/var/www/html -P --name geoffwilliams.me.uk geoffwilliams/geoffwilliams.me.uk:dev bash
