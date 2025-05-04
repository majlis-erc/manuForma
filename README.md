# manuForma [BETA]

[![DOI](https://zenodo.org/badge/474991717.svg)](https://zenodo.org/badge/latestdoi/474991717)

The manuForma application is designed to make TEI data creation and distributed editing faster and easier. The application features easy to use multi-step forms, Github interactions and more.

Custom XForms are built using an XSLT stylesheet, a custom XML configuration file, and a custom XML Schema. The schema is used to define the elements and attributes required for your project. The schema must define all of the elements and attributes you would like in your forms. All controlled values, labels, language, and available elements and attributes will be defined in your custom schema. The more restrictive your schema is the faster your forms will perform. 

TEI is a complex and large schema, so it is necessary to break the forms up into sub-forms. The sub-forms make for easier data entry and faster form load and processing time. We recommend breaking your TEI files up into the smallest meaningful blocks that you can. The application comes bundled with a few example forms, including TEI manuscripts. Use these example forms as templates to build your own custom forms. 

We use our manuscripts forms as an example for the documentation, there are also, forms for person and place records. The manuscript forms are broken up into 8 different sub-forms as shown below.

## Building the forms
Structure of the configuration file: [`forms/formGenerator/config.xml`](src/main/xar-resources/forms/formGenerator/config.xml)

General settings including Application Name, a base url for generating working navigation once the application has been deployed. Form titles, and descriptions. 
```
<config>
    <formBrandName>manuForma</formBrandName>
    <formURL>/exist/apps/manuForma/</formURL>
    <formTitle>Edit MSS TEI records</formTitle>
    <formName>mssTEI</formName>
    <formAuthor>majlis-erc</formAuthor>
    <formDesc>Create and edit MSS records for MAJLIS: The Transformation of Jewish Literature in Arabic in the Islamicate World.</formDesc>
    <formLang>en</formLang>
```

BlankTemplates define a starting template to load into the form, mulitple templates can be defined. 
```
    <blankTemplates>
        <template name="Generic MSS Template" src="/forms/templates/full-mss-template.xml"></template>
    </blankTemplates>
```

Each subform will need a schema and a template. You will need to include the XPath to the top level element for each subform as well as a name (no spaces or special characters) and a label which will appear in the form navigation. 
```
    <subforms>
        <subform xpath="/descendant::tei:titleStmt" formName="titleStmt" formLabel="Title">
            <formDesc>Record title information</formDesc>
            <localSchema src="../schemas/titleStmt.xml"></localSchema>
            <globalSchema src="../schemas/mss-compiled.odd"></globalSchema>
            <xmlTemplate src="../templates/full-mss-template.xml"></xmlTemplate>
        </subform>
        ....
    </subforms>
```

The forms use a two step process, a ‘local schema’ which should be a very restricted schema for the exact elements you would like included in your forms and a ‘global schema’ which should be a full(er) version of the TEI Schema that the forms can use as a fall back to find element/attribute rules. Note, you can use your 'local schema' for both if you do not need your form to fall back on the full schema. 

To create usable and quick forms it is important to be as restrictive as possible when designing your local shema. For example, only reference child elements that you will use, avoid broad classes or module references such as pLike. Instead for a paragraph, simply use a textNode as the only child. The XForms do not do well with mixed content nodes, so you will have to avoid this in your data design. 

To build the form you will simply need to run the XSLT, it will use the values defined in your config.xml file to generate the necessary files to create all the form components necessary. Once the form is built, ant can be run and the application can be deployed to eXist-db. Forms were built and tested with eXist-db 6.3.0 and up. 
