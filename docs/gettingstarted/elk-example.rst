===========================
Example: Linking Containers
===========================

Flocker-0.1.2 introduces support for `Docker Container Linking`_.
In this example you will learn how to deploy ``ElasticSearch``, ``Logstash``, and ``Kibana`` with Flocker, demonstrating how applications running in separate Docker containers can be linked together such that they can connect to one another, even when they are deployed on separate nodes.

The three applications are connected as follows:

* ``Logstash`` receives logged messages and relays them to ``ElasticSearch``.
* ``ElasticSearch`` stores the logged messages in a database.
* ``Kibana`` connects to ``ElasticSearch`` to retrieve the logged messages and present them in a web interface.

We'll start by deploying all three applications on node1.
Then we'll generate some log messages and view them in the ``Kibana`` web interface.
Finally we'll use ``flocker-deploy`` to move the ``ElasticSearch`` container to the second node.
The ``ElasticSearch`` data will be moved with the application and the ``Logstash`` and ``Kibana`` applications will now connect to ``ElasticSearch`` on node2.


Create the Virtual Machines
===========================

We'll use the same Vagrant environment as in the :doc:`MongoDB tutorial <./tutorial/index>`.
If you haven't already started up the Vagrant virtual machines follow the :ref:`setup instructions <VagrantSetup>`.

.. warning:: The Flocker application links feature demonstrated in this example was introduced in Flocker-0.1.2.
          If you have previously run the tutorial using an older version of Flocker, you must destroy and recreate the Vagrant environment.


Download the Docker Images
==========================

In this step we will prepare the nodes by downloading all the required Docker images.

.. code-block:: console

   alice@mercury:~/flocker-tutorial$ ssh -t root@172.16.255.250 docker pull clusterhq/elasticsearch
   ...
   alice@mercury:~/flocker-tutorial$ ssh -t root@172.16.255.250 docker pull clusterhq/logstash
   ...
   alice@mercury:~/flocker-tutorial$ ssh -t root@172.16.255.250 docker pull clusterhq/kibana
   ...
   alice@mercury:~/flocker-tutorial$

.. code-block:: console

   alice@mercury:~/flocker-tutorial$ ssh -t root@172.16.255.251 docker pull clusterhq/elasticsearch
   ...
   alice@mercury:~/flocker-tutorial$ ssh -t root@172.16.255.251 docker pull clusterhq/logstash
   ...
   alice@mercury:~/flocker-tutorial$ ssh -t root@172.16.255.251 docker pull clusterhq/kibana
   ...
   alice@mercury:~/flocker-tutorial$

.. note:: We use the ``-t`` option to ``ssh`` so that progress is displayed.
          If you omit it, the pull will still work but you may not get any output for a long time.


Deploy on Node1
===============

Download and save the following configuration files to your ``flocker-tutorial`` directory:

:download:`elk-application.yml`

.. literalinclude:: elk-application.yml
   :language: yaml

:download:`elk-deployment.yml`

.. literalinclude:: elk-deployment.yml
   :language: yaml

Run ``flocker-deploy`` to start the three applications:

.. code-block:: console

   alice@mercury:~/flocker-tutorial$ flocker-deploy elk-deployment.yml elk-application.yml
   alice@mercury:~/flocker-tutorial$

In the Flocker application configuration above, we have defined a link between the ``Logstash`` and ``Elasticsearch`` containers by specifying the ports and an alias for the application container we want to link.

All three applications should now be running in separate containers on node1.
You can verify this by running ``docker ps`` over an SSH connection:

.. code-block:: console

   alice@mercury:~/flocker-tutorial$ ssh root@172.16.255.250 docker ps
   CONTAINER ID        IMAGE                                 COMMAND                CREATED             STATUS              PORTS                              NAMES
   abc5c08557d4        clusterhq/kibana:latest          /usr/bin/twistd -n w   20 seconds ago      Up 19 seconds       0.0.0.0:80->8080/tcp               kibana
   b4e9f08b3d1d        clusterhq/elasticsearch:latest   /bin/sh -c 'source /   21 seconds ago      Up 19 seconds       9300/tcp, 0.0.0.0:9200->9200/tcp   elasticsearch
   44a4ee72d9ab        clusterhq/logstash:latest        /bin/sh -c /usr/loca   21 seconds ago      Up 19 seconds       0.0.0.0:5000->5000/tcp             logstash
   alice@mercury:~/flocker-tutorial$


Connect to ``Kibana``
=====================

Browse to port 80 on node1 (http://172.16.255.250) with your web browser.
You should see the ``Kibana`` web interface but there won't be any messages yet.

.. image:: elk-example-kibana-empty.png
   :alt: The Kibana web interface shows that in the last day there have been no events.

Generate Log Messages
=====================

````Logstash```` has been configured to accept JSON encoded messages on port 5000.
So next we'll use ``telnet`` to connect to ``Logstash`` port 5000 and feed it some messages using ``telnet``.

.. code-block:: console

   alice@mercury:~/flocker-tutorial$ telnet 172.16.255.250 5000
   {"firstname": "Joe", "lastname": "Bloggs"}
   {"firstname": "Fred", "lastname": "Bloggs"}
   ^]

   telnet> quit
   Connection closed.
   alice@mercury:~/flocker-tutorial$

Now refresh the ``Kibana`` web interface and you should see those messages.

.. image:: elk-example-kibana-messages1.png
   :alt: The Kibana web interface shows that there have been two events in the last five minutes.


Move ``ElasticSearch`` to node2
===============================

Edit the ``elk-deployment.yml`` file so that ``ElasticSearch`` is on node2.
It should now look like:

.. literalinclude:: elk-deployment-moved.yml
   :emphasize-lines: 4
   :language: yaml

Now run ``flocker-deploy`` with the new configuration:

.. code-block:: console

   alice@mercury:~/flocker-tutorial$ flocker-deploy elk-deployment.yml elk-application.yml
   alice@mercury:~/flocker-tutorial$

Now we'll verify that the ``ElasticSearch`` application has moved to the other VM:

.. code-block:: console

   alice@mercury:~/flocker-tutorial$ ssh root@172.16.255.251 docker ps
   CONTAINER ID        IMAGE                                 COMMAND                CREATED             STATUS              PORTS                              NAMES
   894d1656b74d        clusterhq/elasticsearch:latest   /bin/sh -c 'source /   2 minutes ago       Up 2 minutes        9300/tcp, 0.0.0.0:9200->9200/tcp   elasticsearch

And is no longer running on the original host:

.. code-block:: console

   alice@mercury:~/flocker-tutorial$ ssh root@172.16.255.250 docker ps
   CONTAINER ID        IMAGE                            COMMAND                CREATED             STATUS              PORTS                    NAMES
   abc5c08557d4        clusterhq/kibana:latest     /usr/bin/twistd -n w   45 minutes ago      Up 45 minutes       0.0.0.0:80->8080/tcp     kibana
   44a4ee72d9ab        clusterhq/logstash:latest   /bin/sh -c /usr/loca   45 minutes ago      Up 45 minutes       0.0.0.0:5000->5000/tcp   logstash
   alice@mercury:~/flocker-tutorial$

If you refresh the ``Kibana`` web interface, you should see the log messages that were logged earlier.
If you generate more log messages, they should show up in the ``Kibana`` web interface.


Conclusion
==========

This concludes our example for using Flocker with ``ElasticSearch``, ``Logstash``, and ``Kibana``.

You have seen how applications can be configured so that they are able to connect to on another across nodes.
And you have once again seen how Flocker will quickly and transparently move a Docker container and its data between nodes.

.. _`PostgreSQL`: https://www.postgresql.org/download/
.. _`Docker Container Linking`: http://docs.docker.com/userguide/dockerlinks/
