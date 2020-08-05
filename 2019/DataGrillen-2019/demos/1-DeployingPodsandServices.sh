ssh aen@c1-master1

#Deploy a pod in a Deployment
kubectl run hello-world --image=gcr.io/google-samples/hello-app:1.0

#Let's follow our pod and deployment status
#Deployments are made of ReplicaSets!
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

#Access the service inside the cluster
SERVERIP=$(kubectl get service | grep hello-world | awk {'print $3'})
echo $SERVERIP


curl http://$SERVERIP:80

#We can edit the resources "on the fly" with kubectl edit. But this isn't reflected in our yaml. But is
#persisted in the etcd database...cluster store. Change 1 to 3.
kubectl edit deployment hello-world

kubectl scale deployment hello-world --replicas=10

#Get a list of the pods running
kubectl get pods

#Access the application again, try it several times, app will load balance.
curl http://$SERVERIP:80

kubectl delete service hello-world
kubectl delete deployment hello-world
kubectl get all
