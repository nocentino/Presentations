# Install the required packages using pip
# pip install requests pandas prophet

# Launch python3 at the cli

import requests, platform
import time, sys, os, re
import pandas
from prophet import Prophet



# Prometheus API endpoint for query get from environment variable
URL ='http://localhost:9090/api/v1/query'


# CPU Query
PROMQL1 = {'query':"sqlserver_cpu_sqlserver_process_cpu[1d]"}


# Get the response from the prometheus API
r1 = requests.get(url = URL, params = PROMQL1)
r1

# Convert the response to json and return just the time stamp and the metric value
r1_json = r1.json()


# Take a look at the json response
print(r1_json)



# for each result in the response create a data structure to hold the sql_instance name and a data frame of the returned data and add it to the list of data frames
dataframes = []
for result in r1_json['data']['result']:
    my_sql_instance = result['metric'].get('sql_instance')
    my_metric_name = result['metric'].get('__name__')
    my_dataframe = pandas.DataFrame(result['values'], columns=['ds', 'y'])
    dataframes.append({'sql_instance': my_sql_instance, 'metric_name': my_metric_name, 'dataframe': my_dataframe})



# Let't take a look at the dataframes
dataframes


# Let's look at the first dataframe, the sql_instance name and the metric name
df = dataframes[0]['dataframe']
my_predicted_sql_instance = dataframes[0]['sql_instance']
predicted_metric_name = dataframes[0]['metric_name']


# Print the sql_instance name and the metric name
print("\nPredicting for: " + my_predicted_sql_instance + 
      "\tMetric: " + predicted_metric_name + 
      "\tNumber of metrics to be evaluated: " + str(df.y.count()) )


# Use prophet to predict a value 30 seconds in the future based off of the data in the data frame
df['ds'] = pandas.to_datetime(df['ds'], unit='s')
m = Prophet(changepoint_prior_scale=1.0)
m.fit(df)
future = m.make_future_dataframe(periods=30, freq='s')      #Automatically fits to sampling interval in the data set, here its 30 seconds
forecast = m.predict(future)                                #Will predict each interval up until the number of periods


# Let's look at the last 5 rows of the source data frame
df.tail()


# Let's look at the last 5 rows of the forecast
forecast[['ds', 'yhat', 'yhat_lower', 'yhat_upper']].tail()



# Load up the predicted value and the lower and upper bounds, only non-negative values are allowed
predicted_metric_value_yhat  = max ( 0, forecast[['yhat']].tail(1).values[0][0] )
predicted_metric_value_lower = max ( 0, forecast[['yhat_lower']].tail(1).values[0][0] )
predicted_metric_value_upper = max ( 0, forecast[['yhat_upper']].tail(1).values[0][0] )


# print the predicted values to the console
print("\n\n\nPrometheus Results Evaluated: " + str(df.y.count()) 
      + "\nPredicted Value: " + str(predicted_metric_value_yhat) 
      + "\nLower Bound: " + str(predicted_metric_value_lower) 
      + "\nUpper Bound: " + str(predicted_metric_value_upper))
