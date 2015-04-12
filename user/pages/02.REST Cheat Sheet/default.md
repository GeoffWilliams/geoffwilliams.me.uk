---
title: REST Cheat Sheet
---
# REST Cheat Sheet

## Example service URI
https://foobar.com/collection/element

## Interface
| Verb    | Collection                              | Element            | Success code   |
| ------- | --------------------------------------- | ------------------ | -------------- |
| GET     | List                                    | Representation     | 200 OK         |
| POST    | Create element with system assigned URI | Not used           | 201 CREATED    |
| PUT     | Replace collection                      | Replace element    | 201 CREATED    |
| DELETE  | Delete collection                       | Delete element     | 204 NO CONTENT |
| OPTIONS | Describe interface                      | Describe interface | 200 OK         |
| HEAD    | Metadata                                | Metadata           | 200 OK         |

## Key concepts
Idempotent – same result each time (PUT, DELETE)
Safe method (nullipotent) – no side effects (GET)

## Top HTTP status codes
200 OK
201 CREATED
204 NO_CONTENT
400 BAD_REQUEST
401 UNAUTHORIZED
403 FORBIDDEN
404 NOT_FOUND
409 CONFLICT

[Full list](http://en.wikipedia.org/wiki/List_of_HTTP_status_codes)

## Strategies for delivering different content
* URI based (*.xml, *.json, *.jpg, …)
* ACCEPT header mime type list on requests. Then either deliver content using 3xx redirect code or select the most appropriate representation and deliver it directly

## Versioning strategy
* Build the service version number into the URI
* Use the ACCEPT header
