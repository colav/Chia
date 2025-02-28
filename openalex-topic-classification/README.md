<img src="https://raw.githubusercontent.com/colav/colav.github.io/master/img/Logo.png"/>

# OpenAlex Topic Classification
Model to predict the topic of a document using a pre-trained model.
Modified from https://github.com/ourresearch/openalex-topic-classification/tree/main

# Description
This package allows to setup a docker container with OpenAlex Topic AI model for inference through and API.

# Installation

## Dependencies
Docker and docker-compose is required.
* https://docs.docker.com/engine/install/ubuntu/ (or https://docs.docker.com/engine/install/debian/, etc)
* Install `docker-compose`:  
```bash
apt install docker-compose
```
or
```bash
pip install docker-compose
```

* https://docs.docker.com/engine/install/linux-postinstall/


# Usage

```bash
docker-compose up
``` 

# API
The API is available at http://localhost:
```py
import requests
import json

payload = [
  {"title":"Multiplication of matrices of arbitrary shape on a data parallel computer",
    "abstract_inverted_index": {"Some": [0],
      "level-2": [1],
      "and": [2],
      "level-3": [3],
      "Distributed": [4],
      "Basic": [5],
      "Linear": [6],
      "Algebra": [7],
      "Subroutines": [8],
      "(DBLAS)": [9],
      "that": [10],
      "have": [11],
      "been": [12],
      "implemented": [13],
      "on": [14, 26],
      "the": [15, 27],
      "Connection": [16],
      "Machine": [17],
      "system": [18],
      "CM-200": [19],
      "are": [20],
      "described.": [21],
      "No": [22],
      "assumption": [23],
      "is": [24],
      "made": [25],
      "shape": [28],
      "or": [29],
      "...": [30]},
    "inverted": True,
    "referenced_works": ["https://openalex.org/W183327403",
      "https://openalex.org/W1851212222",
      "https://openalex.org/W1967958850",
      "https://openalex.org/W1988425770",
      "https://openalex.org/W1991286031",
      "https://openalex.org/W2029342163",
      "https://openalex.org/W2045381439",
      "https://openalex.org/W2053280233",
      "https://openalex.org/W2071782145",
      "https://openalex.org/W2083202979",
      "https://openalex.org/W2104487100",
      "https://openalex.org/W4234919994"],
    "journal_display_name": "Fire Safety Science"}
]

req=requests.post("http://localhost:8080/invocations",json=payload)
if req.status_code==200:
    topic_url_base="https://api.openalex.org/topics/T"
    data=req.json()
    print(data[0][0])
    req_oa=requests.get(topic_url_base+str(data[0][0]['topic_id']))
    if req_oa.status_code == 200:
        print(json.dumps(req_oa.json(), indent=2))
```

The output is something like

```bash
{'topic_id': 10829, 'topic_label': '829: Networks on Chip in System-on-Chip Design', 'topic_score': 0.9978}

{
  "id": "https://openalex.org/T10829",
  "display_name": "Interconnection Networks and Systems",
  "description": "This cluster of papers focuses on the design, architecture, and optimization of Networks on Chip (NoC) within System-on-Chip (SoC) designs. It covers topics such as interconnection networks, routing algorithms, performance evaluation, power optimization, wireless interconnects, fault tolerance, and multi-core processors.",
  "keywords": [
    "Networks on Chip",
    "Interconnection Networks",
    "System-on-Chip",
    "NoC Architecture",
    "Routing Algorithms",
    "Performance Evaluation",
    "Power Optimization",
    "Wireless Interconnects",
    "Fault Tolerance",
    "Multi-core Processors"
  ],
  "ids": {
    "openalex": "https://openalex.org/T10829",
    "wikipedia": "https://en.wikipedia.org/wiki/Network_on_a_chip"
  },
  "subfield": {
    "id": "https://openalex.org/subfields/1705",
    "display_name": "Computer Networks and Communications"
  },
  "field": {
    "id": "https://openalex.org/fields/17",
    "display_name": "Computer Science"
  },
  "domain": {
    "id": "https://openalex.org/domains/3",
    "display_name": "Physical Sciences"
  },
  "siblings": [
    {
      "id": "https://openalex.org/T11504",
      "display_name": "Advanced Authentication Protocols Security"
    },
    {
      "id": "https://openalex.org/T11181",
      "display_name": "Advanced Data Storage Technologies"
    },
    {
      "id": "https://openalex.org/T10317",
      "display_name": "Advanced Database Systems and Queries"
    },
    {
      "id": "https://openalex.org/T13748",
      "display_name": "Advanced Statistical Modeling Techniques"
    },
    {
      "id": "https://openalex.org/T13345",
      "display_name": "Advanced Technologies and Applied Computing"
    },
    {
      "id": "https://openalex.org/T13553",
      "display_name": "Age of Information Optimization"
    },
    {
      "id": "https://openalex.org/T12801",
      "display_name": "Bluetooth and Wireless Communication Technologies"
    },
    {
      "id": "https://openalex.org/T11478",
      "display_name": "Caching and Content Delivery"
    },
    {
      "id": "https://openalex.org/T10579",
      "display_name": "Cognitive Radio Networks and Spectrum Sensing"
    },
    {
      "id": "https://openalex.org/T11596",
      "display_name": "Constraint Satisfaction and Optimization"
    },
    {
      "id": "https://openalex.org/T10796",
      "display_name": "Cooperative Communication and Network Coding"
    },
    {
      "id": "https://openalex.org/T13807",
      "display_name": "Cultural Insights and Digital Impacts"
    },
    {
      "id": "https://openalex.org/T13983",
      "display_name": "Cybersecurity and Information Systems"
    },
    {
      "id": "https://openalex.org/T10715",
      "display_name": "Distributed and Parallel Computing Systems"
    },
    {
      "id": "https://openalex.org/T10249",
      "display_name": "Distributed Control Multi-Agent Systems"
    },
    {
      "id": "https://openalex.org/T12879",
      "display_name": "Distributed Sensor Networks and Detection Algorithms"
    },
    {
      "id": "https://openalex.org/T10772",
      "display_name": "Distributed systems and fault tolerance"
    },
    {
      "id": "https://openalex.org/T13836",
      "display_name": "Educational Research and Pedagogy"
    },
    {
      "id": "https://openalex.org/T10080",
      "display_name": "Energy Efficient Wireless Sensor Networks"
    },
    {
      "id": "https://openalex.org/T11321",
      "display_name": "Error Correcting Code Techniques"
    },
    {
      "id": "https://openalex.org/T13924",
      "display_name": "Internet of Things and Social Network Interactions"
    },
    {
      "id": "https://openalex.org/T10273",
      "display_name": "IoT and Edge/Fog Computing"
    },
    {
      "id": "https://openalex.org/T13745",
      "display_name": "Media and Digital Communication"
    },
    {
      "id": "https://openalex.org/T10246",
      "display_name": "Mobile Ad Hoc Networks"
    },
    {
      "id": "https://openalex.org/T12203",
      "display_name": "Mobile Agent-Based Network Management"
    },
    {
      "id": "https://openalex.org/T10400",
      "display_name": "Network Security and Intrusion Detection"
    },
    {
      "id": "https://openalex.org/T12216",
      "display_name": "Network Time Synchronization Technologies"
    },
    {
      "id": "https://openalex.org/T10138",
      "display_name": "Network Traffic and Congestion Control"
    },
    {
      "id": "https://openalex.org/T11347",
      "display_name": "Neural Networks Stability and Synchronization"
    },
    {
      "id": "https://openalex.org/T11187",
      "display_name": "Nonlinear Dynamics and Pattern Formation"
    },
    {
      "id": "https://openalex.org/T11896",
      "display_name": "Opportunistic and Delay-Tolerant Networks"
    },
    {
      "id": "https://openalex.org/T12288",
      "display_name": "Optimization and Search Problems"
    },
    {
      "id": "https://openalex.org/T10742",
      "display_name": "Peer-to-Peer Network Technologies"
    },
    {
      "id": "https://openalex.org/T11498",
      "display_name": "Security in Wireless Sensor Networks"
    },
    {
      "id": "https://openalex.org/T12564",
      "display_name": "Sensor Technology and Measurement Systems"
    },
    {
      "id": "https://openalex.org/T13693",
      "display_name": "Smart Systems and Machine Learning"
    },
    {
      "id": "https://openalex.org/T12127",
      "display_name": "Software System Performance and Reliability"
    },
    {
      "id": "https://openalex.org/T10714",
      "display_name": "Software-Defined Networks and 5G"
    },
    {
      "id": "https://openalex.org/T14455",
      "display_name": "Technology and Education Systems"
    },
    {
      "id": "https://openalex.org/T10575",
      "display_name": "Wireless Communication Networks Research"
    },
    {
      "id": "https://openalex.org/T11158",
      "display_name": "Wireless Networks and Protocols"
    },
    {
      "id": "https://openalex.org/T14353",
      "display_name": "Wireless Sensor Networks for Data Analysis"
    }
  ],
  "works_count": 62323,
  "cited_by_count": 745810,
  "updated_date": "2025-02-17T04:40:44.214798",
  "created_date": "2024-01-23"
}
```

Please change .env file before deploy in production

# License
BSD-3-Clause License 

# Links
http://colav.udea.edu.co/

