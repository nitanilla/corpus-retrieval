# [The Corpus Builder](https://corpus-retrieval.herokuapp.com/)  
###The Readme Retrieval
Tool useful for collection of readmes given a query, the same query that you may do in GitHub. This work boost the discovering of information and the reuse. 
All depends of the point of view.  
The corpus obtained can be useful to begin to explore data with text-mining techniques. 

## Getting Started
The working version can be located in:  
[corpus-retrieval.herokuapp.com](https://corpus-retrieval.herokuapp.com/)  

NOTE: the code presented here is optimized with the following  
[proxy](https://github.com/nitanilla/github-proxy)

## Executing the project locally
To use this Code, choose one of the following options to get started:
* [Download the zip](https://github.com/nitanilla/corpus-retrieval/archive/master.zip)
* *Clone the project*: `git clone https://github.com/nitanilla/corpus-retrieval`

To run the project you have to install:
* [docker](https://docs.docker.com/engine/installation/)
* [docker-compose](https://docs.docker.com/compose/install/).

After installing them follow the steps below to get the server up running:
* `docker-compose build # Create the project image`
* Customize `docker-compose.yml` to use your own CLIENT_IDs, CLIENT_SECRETs and SLAVES.
* `docker-compose up # Run the server listening on port 3000`

## Bugs and Issues
Have a bug or an issue with this? [Open a new issue](https://github.com/nitanilla/corpus-retrieval/issues) here on GitHub 

## Creators
[@nitanilla](https://github.com/nitanilla)
[@hugolnx](https://github.com/hugolnx)

## Copyright and License

Copyleft © 2015 Puc-Rio, LLC.  
Code released under the [GPL 2.0](https://github.com/nitanilla/corpus-retrieval/blob/master/LICENSE) license.
