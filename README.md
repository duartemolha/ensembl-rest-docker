# ensembl-rest-docker
Docker container for setting up an Ensembl REST server

Checkout this git repository:
```
git clone https://github.com/duartemolha/ensembl-rest-docker.git

cd ensembl-rest-docker
```
To build your image you can use one of the ready made .env_template files or created one of your own contaning the same arguments
I.e. Rename one of the 2 .env.template_grch38 or .env.template_grch37 files to .env and modify its contents if you want to connect to a different server. Currently they are set with the default ensembl settings and targeting API release 102 

Build the docker image:

```
bash build.sh \
    --build-name [name_of_container (default: ensembl-rest)] \
    --env-file [env file (default: .env)]

# for example you could just use the ready made template file to create a rest server for GRCH38 as such:
bash build.sh \
    --build-name ensembl-rest-grch38 \
    --env-file .env.template_grch38

```

Run docker container, specifing the expose port on your host machine where the server will be accessed:
```
docker run -d --name [build_name] -p 3000:80 [build_name]
# using default parameters this would be:
docker run -d --name ensembl-rest -p 8080:80 ensembl-rest
```

Test by visiting the port that the docker container was started on:
```
curl 'localhost:8080/lookup/id/ENSG00000157764?' -H 'Content-type:application/json'
```

Result:
```
{"canonical_transcript":"ENST00000646891.2","version":14,"source":"ensembl_havana","biotype":"protein_coding","display_name":"BRAF","start":140719327,"strand":-1,"assembly_name":"GRCh38","logic_name":"ensembl_havana_gene_homo_sapiens","db_type":"core","object_type":"Gene","description":"B-Raf proto-oncogene, serine/threonine kinase [Source:HGNC Symbol;Acc:HGNC:1097]","species":"homo_sapiens","id":"ENSG00000157764","seq_region_name":"7","end":140924929}
```
