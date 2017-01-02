A complete "social kernel" database and back-end, to be implemented with [PostgreSQL 9.6+](https://www.postgresql.org/docs/current/static/functions-json.html) and some "Agile Framework" (as Django, Spring, CakePHP, etc.) ; based on **[socKer-simple](https://github.com/ppKrauss/socKer-simple)**.

-----

It is a model to be used as core at any  [CRM](https://en.wikipedia.org/wiki/Customer_relationship_management)-like system... With precise information and a [RDF semantic](https://en.wikipedia.org/wiki/Resource_Description_Framework). The basic entities are defined in [SchemaOrg](https://schema.org/):

* **_Person_**: any [sc:Person](https://schema.org/Person) with a [name](https://schema.org/name) and a valid [sc:vatID](https://schema.org/vatID), and other JSON-stored informations.

* **_Organization_**: any [sc:Organization](https://schema.org/Organization) with a  [name](https://schema.org/name) and a valid [sc:vatID](https://schema.org/vatID), and other JSON-stored informations (see eg. [gs1:OrganizationRoleType](http://gs1.org/voc/OrganizationRoleType)).

* **_Agent_**: a generalization of _Person_ and _Organization_ (the union of both), as "formal person" ([wd:legal person](https://www.wikidata.org/wiki/Q3778211) and [wd:natural person](https://www.wikidata.org/wiki/Q154954)).  See [foaf:Agent](http://xmlns.com/foaf/spec/#term_Agent) definition.

* **_Telecom_**: information about [wd:telecommunication](https://www.wikidata.org/wiki/Q418) device (its eletronic address) of an _Agent_: telephone, e-mail, homepage, etc.

* **_Place_**: information about a place or subplace, as volume in the geographical space, like an edification, a house, an apartment, a park, a shopping center, etc.

* **_ContactPoint_**: [sc:ContactPoint](https://schema.org/ContactPoint), splitted in two disjoint types: 

  * **_TelecomPoint_**: relates _Agent_ with _Telecom_, as an usual _ContactPoint_.

  * **_PlacePoint_**: relates _Agent_ with _Place_, as an usual [sc:PostalAddress](https://schema.org/PostalAddress) or similar _Place_ relation. 
  
The main enhances about previous didactic [socKer-simple](https://github.com/ppKrauss/socKer-simple)  are:

* add _Place_ as optional _ContactPoint_, for postal adress and geographical references.
* add agent-agent relationships (_AgentsRelation) that enhance the informations of the catalogue. 
* add secondary relations: _AgentsRelation_'s _ContanctPoint_ for special cases (eg. [foaf:workplaceHomepage](http://xmlns.com/foaf/spec/#term_workplaceHomepage) as a _TelecomPoint_ of a Person-Organization relation); Place-ContactPoint relations as [ch:areaServed](https://schema.org/areaServed) (or [sc:validIn](https://schema.org/validIn), [sc:geographicArea](https://schema.org/geographicArea), etc.), extended for Place-Place relations (eg. [sc:containedInPlace](https://schema.org/containedInPlace)).

Examples of agent-agent relationships (modeled as **AgentsRelation** class):

Relation type | *rule* examples (of SchemaOrg)
------------ | -------------
Organization-Organization      | [subOrganization](https://schema.org/subOrganization), [LocalBusiness](https://schema.org/LocalBusiness), [sponsor](https://schema.org/sponsor), ...
Organization-Person   | [founder](https://schema.org/founder), [employee](https://schema.org/employee), [sponsor](https://schema.org/sponsor), [affiliation](https://schema.org/affiliation), ...
Person-Person | [children](https://schema.org/children), ...
Agent-Agent | [follows](https://schema.org/follows), ...

## Objective
To implement this model **with good back-end Framework and good SQL**, incrementally

1. As [build1.sql](src/build1.sql) ![](https://yuml.me/5308ec31)

2. As [build2.sql](src/build2.sql) ![](https://yuml.me/5656b1e1)

3. As [build3.sql](src/build3.sql) ![](https://yuml.me/b48630a2)
