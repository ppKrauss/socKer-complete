A complete "social kernel" database and back-end, to be implemented with [PostgreSQL 9.6+](https://www.postgresql.org/docs/current/static/functions-json.html) and some "Agile Framework" (as Django, Spring, CakePHP, etc.) ; based on [socKer-simple](https://github.com/ppKrauss/socKer-simple).

It is a model to be used as core at any  [CRM](https://en.wikipedia.org/wiki/Customer_relationship_management))-like system... With precise information and a [RDF semantic](https://en.wikipedia.org/wiki/Resource_Description_Framework). The basic entities are defined in [SchemaOrg](https://schema.org/):

* **_Person_**: any [sc:Person](https://schema.org/Person) with a [name](https://schema.org/name) and a valid [sc:vatID](https://schema.org/vatID).

* **_Organization_**: any [sc:Organization](https://schema.org/Organization) with a  [name](https://schema.org/name) and a valid [sc:vatID](https://schema.org/vatID).

* **_Agent_**: a generalization of Person and Organization (the union of both), as "formal person" ([wd:legal person](https://www.wikidata.org/wiki/Q3778211) and [wd:natural person](https://www.wikidata.org/wiki/Q154954)).  See [foaf:Agent](http://xmlns.com/foaf/spec/#term_Agent) definition.

* **_TeleCom_**: information about telecommunication-[sc:ContactPoint](https://schema.org/ContactPoint) of an _Agent_. Telephone, e-mail, homepage, etc. addresses.

* **_LocalContanct_**: information about local-[sc:ContactPoint](https://schema.org/ContactPoint) of an _Agent_. Correspondence addresses, deliver address, etc.

* **_Place_**: information about a place or subplace, as volume in the geographical space, like an edification, a house, an apartment, a park, a shopping center, etc.

The main enhances about  [socKer-simple](https://github.com/ppKrauss/socKer-simple)  are:

* add Place as optional ContactPoint for PostalAdress's, etc.
* add agent-agent relationships that enhance the informations of the catalogue. 

Examples of agent-agent relationships:

Relation type | *rule* examples (of SchemaOrg)
------------ | -------------
Organization-Organization      | [subOrganization](https://schema.org/subOrganization), [sponsor](https://schema.org/sponsor), ...
Organization-Person   | [founder](https://schema.org/founder), [employee](https://schema.org/employee), [sponsor](https://schema.org/sponsor), [affiliation](https://schema.org/affiliation), ...
Person-Person | [children](https://schema.org/children), ...
Agent-Agent | [follows](https://schema.org/follows), ...

## Objective
To implement this model **with good Back-end Framework and good SQL**, 

![](https://yuml.me/76e02566)

And to enhance with

![](https://yuml.me/a6e58cfd)

and 

![](https://yuml.me/95dd7d97)
