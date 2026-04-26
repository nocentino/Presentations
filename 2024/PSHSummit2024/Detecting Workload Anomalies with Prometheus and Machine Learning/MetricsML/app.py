import requests, platform
import time, sys, os, re
import pandas
from prophet import Prophet
from prometheus_client import Gauge, make_wsgi_app
from wsgiref.simple_server import make_server


# Class to hold the sql instance name and the dictionary of metrics
class sql_instance:
    def __init__(self, sql_instance_name):
        self.sql_instance_name = sql_instance_name
        self.metrics = {}
        

def get_prometheus_data():
    # Prometheus api endpoint for query get from environment variable
    URL = os.getenv('PROMETHEUS')


    # CPU Query
    DAYSBACK = os.getenv('DAYSBACK')
    PROMQL1 = {'query':"sqlserver_cpu_sqlserver_process_cpu[" + DAYSBACK + "]"}


    # Get the response from the prometheus API
    r1 = requests.get(url = URL, params = PROMQL1)


    # Convert the response to json and return just the time stamp and the metric value
    r1_json = r1.json()


    # for each result in the response create a data structure to hold the sql_instance name and a data frame of the returned data and add it to the list of data frames
    dataframes = []
    for result in r1_json['data']['result']:
        my_sql_instance = result['metric'].get('sql_instance')
        my_metric_name = result['metric'].get('__name__')
        my_dataframe = pandas.DataFrame(result['values'], columns=['ds', 'y'])
        dataframes.append({'sql_instance': my_sql_instance, 'metric_name': my_metric_name, 'dataframe': my_dataframe})


    return dataframes


def get_predictions():
    # Get the data from get_prometheus_data
    dataframes = get_prometheus_data()
    

    # Array to hold the sql_instance objects
    my_sql_instances = []
    
    
    # For each data frame in the dataframes list get the data and predict the next value
    for data in dataframes:
        df = data['dataframe']
        my_predicted_sql_instance = data['sql_instance']
        predicted_metric_name = data['metric_name']
        print("\nPredicting for: " + my_predicted_sql_instance + "\tMetric: " + predicted_metric_name + "\tNumber of metrics evaluated: " + str(df.y.count()) )

        
        # Use prophet to predict a value 30 seconds in the future based off of the data in the data frame
        df['ds'] = pandas.to_datetime(df['ds'], unit='s')
        m = Prophet(changepoint_prior_scale=1.0)
        m.fit(df)
        future = m.make_future_dataframe(periods=30, freq='s')      #Automatically fits to sampling interval in the data set, here its 30 seconds
        forecast = m.predict(future)                                #Will predict each interval up until the number of periods
    
        
        # Load up the predicted value and the lower and upper bounds, only non-negative values are allowed
        predicted_metric_value_yhat  = max ( 0, forecast[['yhat']].tail(1).values[0][0] )
        predicted_metric_value_lower = max ( 0, forecast[['yhat_lower']].tail(1).values[0][0] )
        predicted_metric_value_upper = max ( 0, forecast[['yhat_upper']].tail(1).values[0][0] )
    
    
        # Extract the metric name, hostname from the json response. Build the string that is the new metric name.
        predicted_metric_name_yhat = predicted_metric_name + '_yhat'
        predicted_metric_name_yhat_lower = predicted_metric_name + '_yhat_lower'
        predicted_metric_name_yhat_upper = predicted_metric_name + '_yhat_upper'


    
        # Create a dictonary for the predicted metric values and the lower and upper bounds
        predicted_metrics = {
            predicted_metric_name_yhat: predicted_metric_value_yhat, 
            predicted_metric_name_yhat_lower: predicted_metric_value_lower, 
            predicted_metric_name_yhat_upper: predicted_metric_value_upper}
    
    
        # instantiate the sql_instance class
        my_sql_instance = sql_instance(my_predicted_sql_instance)
        my_sql_instance.metrics = predicted_metrics
    
    
        # Append the sql_instance object to the my_sql_instances list
        my_sql_instances.append(my_sql_instance)
    
    
    # print all of the sql_instance objects to the console
    for instance in my_sql_instances:
        print("\nSQL Instance: " + instance.sql_instance_name)
        for metricname, metricvalue in instance.metrics.items():
            print("\tMetric: " + metricname + "\tValue: " + str(metricvalue))
            
    return my_sql_instances

def get_metrics():
    predicted_metrics = get_predictions()
    
    # if this is the first time the page create a gauge metric for the first instance in the predicted_metrics list
    if not hasattr(get_metrics, 'gauge'):
        get_metrics.gauge = {}
        
        # create a gauge metric for each metric in the first instance in the predicted_metrics list
        instance = predicted_metrics[0]
        for metricname, metricvalue in instance.metrics.items():
            get_metrics.gauge[metricname] = Gauge(metricname, 'Predicted Metric : ' + metricname, ['sql_instance'])
  
    # Update the gauge metrics
    for instance in predicted_metrics:
        for metricname, metricvalue in instance.metrics.items():
            get_metrics.gauge[metricname].labels(sql_instance=instance.sql_instance_name).set(metricvalue)


def my_app(environ, start_fn):
    if environ['PATH_INFO'] == '/metrics':
        get_metrics()
        return metrics_app(environ, start_fn)
    start_fn('200 OK', [])
    return [b'MetricsML Server v0.01\n']

if __name__ == '__main__':
    metrics_app = make_wsgi_app()
    httpd = make_server('', 8000, my_app)
    httpd.serve_forever()