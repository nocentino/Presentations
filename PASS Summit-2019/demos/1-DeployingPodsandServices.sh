#Log into master node to drive demos
ssh aen@c1-master1


cd ~/content/Talks/Kubernetes/PASS\ Summit/demos
PS1='\u@\h:\W\$ '


#Deploy a pod in a Deployment
kubectl create deployment hello-world --image=gcr.io/google-samples/hello-app:1.0


#Let's follow our pod and deployment status
#Deployments are made of ReplicaSets! ReplicaSets create Pods. Pods are your apps.
kubectl get deployment hello-world
kubectl get replicaset
kubectl get pods


#Expose the Deployment as a Serivce.
#This will create a Service for the ReplicaSet behind the Deployment
#We are exposing our serivce on port 80, connecting to an application running on 8080 in our pod.
#Port: Interal Cluster Port, the Service's port. You will point cluster resources here.
#TargetPort: The Pod's Serivce Port, your application. That one we defined when we started the pods.
kubectl expose deployment hello-world --port=80 --target-port=8080


#Check out the IP: and Port:, that's where we'll access this service.
kubectl get service hello-world
SVCIP=$(kubectl get service hello-world | grep hello-world | awk {'print $3'})


#Access the service inside the cluster
curl http://$SVCIP


#We can edit the resources "on the fly" with kubectl edit. But this isn't reflected in our yaml. But is
#persisted in the etcd database...cluster store. Change 1 to 3.
kubectl scale deployment hello-world --replicas=3


#Get a list of the pods running
kubectl get pods


#Access the application again, try it several times, app will load balance.
curl http://$SVCIP


#Rollout version 2 of our application
kubectl --record deployment set image hello-world hello-app=gcr.io/google-samples/hello-app:2.0


#Watch the change in desired state
kubectl get deployment


#Access our application, version 2 :P
curl http://$SVCIP


#What about 50...why not? What are some considerations in scaling? Resources of course :)
kubectl scale deployment hello-world --replicas=50


#Get a list of the pods running
kubectl get pods

#Access our application, version 2...50 pods :P
curl http://$SVCIP

kubectl delete service hello-world
kubectl delete deployment hello-world
kubectl get all


################################################################################################
#You can repeat this demo declaratively by using
kubectl apply -f deployment-helloworld.yaml


#Then edit deployment-helloworld.yaml, change Replicas to 3...and deploy the file again
kubectl apply -f deployment-helloworld.yaml


#Then edit deployment-helloworld.yaml, change image on line 15 from :1.0 to :2.0 and redeploy
kubectl apply -f deployment-helloworld.yaml


#Then edit deployment-helloworld.yaml, change Replicas to 50...and deploy the file again...crazy huh?
kubectl apply -f deployment-helloworld.yaml


#Clean up your resources
kubectl delete service hello-world
kubectl delete deployment hello-world
kubectl get all
