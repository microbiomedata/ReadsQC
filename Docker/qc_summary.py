#!/usr/bin/env python
# Chienchi Lo 20240701

import os
import argparse
import plotly
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import pandas as pd
import json

def is_json(myjson):
    try:
        with open(myjson) as f:
            data= json.load(f)
    except json.JSONDecodeError as e:
        data = None
    return data


# Argument parsing
parser = argparse.ArgumentParser()
parser.add_argument('--input', '-i', type=str, help='Input file (filterStats2.txt or filterStats2.json)', required=True)
parser.add_argument('--output', '-o', type=str, help='Output file name', default='qc_summary.html')

args = parser.parse_args()

# Setting default values
output = args.output
input_f = args.input

data  = is_json(input_f)
df = None
if data:
    stats = data
else:  
    df=pd.read_csv(input_f,sep="\t")

if df:
    fig = make_subplots(rows=1, cols=2, column_widths=[0.15, 0.85])
    top2 = df.head(2)
    filters_df = df.iloc[2:]
    fig.add_trace(go.Bar(x=top2['#Class'] ,y=top2['Reads'],
                        texttemplate="%{y}",
                        marker=dict(cornerradius=10),
                        customdata=top2['Bases'],
                        hovertemplate="<br>".join([
                            "Reads: %{y}",
                            "Bases: %{customdata}"]) + "<extra></extra>" ),
                        row=1,col=1)
    fig.add_trace(go.Bar(x=filters_df['#Class'],y=filters_df['Reads'],
                        texttemplate="%{y}",
                        marker=dict(cornerradius=10),
                        customdata=filters_df['Bases'],
                        hovertemplate="<br>".join([
                            "Reads: %{y}",
                            "Bases: %{customdata}"]) + "<extra></extra>" ),
                        row=1,col=2)
    

if stats:
    input_output_data = {key: stats[key] for key in ["Input", "Output"]}
    other_data = {key: stats[key] for key in stats if key not in ["Input", "Output"]}
    fig = make_subplots(rows=1, cols=2, column_widths=[0.40, 0.60])
    fig.add_trace(
        go.Bar(name="Input", x=["Input"], y=[input_output_data["Input"]],marker=dict(cornerradius=10)),
        row=1, col=1
    )
    fig.add_trace(
        go.Bar(name="Output", x=["Output"], y=[input_output_data["Output"]],marker=dict(cornerradius=10)),
        row=1, col=1
    )
    
    for key, value in other_data.items():
        fig.add_trace(
            go.Bar(name=key, x=[key], y=[value],marker=dict(cornerradius=10)),
            row=1, col=2
        )

fig.update_yaxes(title_text="Reads Count", row=1, col=1)
fig.update_layout(title_text='QC summary',showlegend=False)
fig.write_html(output)
