# manuForma
The manuForma application is designed to make TEI data creation and distributed editing faster and easier. The application features easy to use multi-step forms, Github interactions and more.

Custom XForms are built using an XSLT stylesheet and a custom XML configuration file and a custom XML Schema to define the elements and attributes required for your project. The schema must define all of the elements and attributes you would like in your forms. All controlled values, labels, language, and available elements and attributes will be defined in your custom schema. The more restrictive your schema is the faster your forms will perform. 

TEI is a complex and large schema, so it is necessary to break the forms up into subforms. The subforms make for easier data entry and faster form load and processing time. We recommend breaking your TEI files up into the smallest meaningful blocks that you can. We will be using TEI manuscripts as an example. Our manuscripts are broken up into 8 different subforms.

## Building the forms
Structure of the configuration file, forms/formGenerator/config.xml

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

To build the form you will simply need to run the XSLT, it will use the values defined in your config.xml file to generate the necessary files to create all the form components necessary. Once the form is built, ant can be run and the applicaiton can be deployed to eXist-db. Forms built and tested with eXist-db 5.3.1. 
