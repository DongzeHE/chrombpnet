import json
import pandas as pd
import os
import matplotlib.pyplot as plt
import argparse

def read_args():
	parser = argparse.ArgumentParser(description="Make summary reports")
	parser.add_argument('-id', '--input-dir', type=str, help="directory name output by command chrombpnet bias pipeline")
	parser.add_argument('-fp', '--file-prefix', required=False, default=None, type=str, help="File prefix for output to use. All the files will be prefixed with this string if provided.")
	args = parser.parse_args()
	return args
	

def main(args):

	if args.file_prefix:
		fpx = args.file_prefix+"_"
	else:
		fpx = ""
		
	#prefix = "/home/anusri/full_run_tes/bias_model/"
	prefix = args.input_dir
	pd.set_option('colheader_justify', 'center')   # FOR TABLE <th>


	# 1. Set up multiple variables to store the titles, text within the report
	page_title_text='Bias model quality check report'


	# preprocessing defaults
	pre_hed = 'Preprocessing report'
	pre_text = 'The image should closely represent a Tn5 or DNase enzyme motif (indicates correct shift).'

	bias_image_loc=os.path.join("./","{}bw_shift_qc.png".format(fpx))
	
	## training images

	train_hed = 'Training report'

	loss = pd.read_csv(os.path.join(prefix,"logs/{}bias.log".format(fpx)), sep=",", header=0)
	
	val_loss = loss["val_loss"]
	train_loss = loss["loss"]
	epochs = loss["epoch"]
	
	plt.rcParams["figure.figsize"]=4,4
	plt.figure()
	plt.plot(epochs, val_loss, label="val loss")
	plt.plot(epochs, train_loss, label="train loss")
	plt.legend(loc='best')
	plt.xlabel('Epochs')
	plt.ylabel('Total loss')
	plt.tight_layout()
	plt.savefig(os.path.join(prefix,"evaluation/{}epoch_loss.png".format(fpx)),format='png',dpi=300)
	loss_image_loc=os.path.join("./","{}epoch_loss.png".format(fpx))

	## bias model training performance

	bias_model_perf_hed = 'Bias model performance in non-peaks or background regions'
	bias_model_perf_text = 'The pearsonr in should be greater than 0 (higher the better). Median JSD lower the better. Median Norm JSD higher the better. '

	data = json.load(open(os.path.join(prefix,"evaluation/{}bias_nonpeaks_metrics.json".format(fpx))))
	df = pd.json_normalize(data['counts_metrics']).round(2)
	df = pd.json_normalize(data['counts_metrics'])
	df.index = ['counts_metrics']

	df1 = pd.json_normalize(data['profile_metrics']).round(2)
	df1 = pd.json_normalize(data['profile_metrics'])
	df1.index = ['profile_metrics']
	
	## bias model training performance

	bias_model_perf_hed_peaks = 'Bias model performance in peaks'
	bias_model_perf_text_peaks = 'The pearsonr in should be greater than -0.3 (otherwise the bias model has AT bias and bias correction might be incomplete). Median JSD lower the better. Median Norm JSD higher the better. '

	data = json.load(open(os.path.join(prefix,"evaluation/{}bias_peaks_metrics.json".format(fpx))))
	pdf = pd.json_normalize(data['counts_metrics']).round(2)
	pdf = pd.json_normalize(data['counts_metrics'])
	pdf.index = ['counts_metrics']

	pdf1 = pd.json_normalize(data['profile_metrics']).round(2)
	pdf1 = pd.json_normalize(data['profile_metrics'])
	pdf1.index = ['profile_metrics']


	## TFModisco motifs learnt by bias model (bias.h5) model 
	
	def remove_negs(tables):
		new_lines=[]
		set_flag = True
		lines = tables.split("\n")
		jdx=0
		for idx in range(len(lines)-1):
			
			if jdx==15:
				set_flag = True
				jdx=0
	
			if "neg_" in lines[idx+1]:
				set_flag=False
				jdx = 0
		
			if set_flag:
				new_lines.append(lines[idx])
			else:
				jdx+=1
		new_lines.append(lines[-1])
		return  "\n".join(new_lines)
				
		
	tf_hed = "TFModisco motifs learnt from bias model (bias.h5) model"
	tf_text_profile = "TFModisco on Profile head - Only enzyme motifs should be present. cwm_fwd, cwm_rev should be free from any TF motifs. The motifs top matches in TOMTOM are shown (match_0, match_1, match_2). The qvals should be high."
	tf_text_counts = "TFModisco on Counts head. cwm_fwd, cwm_rev should be free from any TF motifs. These results should not be all AT rich sequences. The motifs top matches in TOMTOM are shown (match_0, match_1, match_2). The qvals should be high."

	table_profile = open(os.path.join(prefix,"auxiliary/interpret/modisco_profile/motifs.html")).read().replace("./",os.path.join(prefix,"auxiliary/interpret/modisco_profile/")).replace("width=\"240\"","class=\"cover\"").replace("border=\"1\" class=\"dataframe\"","").replace(">pos_patterns.pattern",">pos_").replace(">neg_patterns.pattern",">neg_").replace("modisco_cwm_fwd","cwm_fwd").replace("modisco_cwm_rev","cwm_rev").replace("num_seqlets","NumSeqs")
	table_counts = open(os.path.join(prefix,"auxiliary/interpret/modisco_counts/motifs.html")).read().replace("./",os.path.join(prefix,"auxiliary/interpret/modisco_counts/")).replace("width=\"240\"","class=\"cover\"").replace("border=\"1\" class=\"dataframe\"","").replace(">pos_patterns.pattern",">pos_").replace(">neg_patterns.pattern",">neg_").replace("modisco_cwm_fwd","cwm_fwd").replace("modisco_cwm_rev","cwm_rev").replace("num_seqlets","NumSeqs")

	table_profile = remove_negs(table_profile)
	table_counts = remove_negs(table_counts)

	#table_profile=None
	#table_counts=None
	#.replace("<td>","<td style=\"width: 20px;height: 40px\">")

	# 2. Combine them together using a long f-string
	html = f'''
		<html>
			<head>
				<title>{page_title_text}</title>
			</head>
			<body>
				<h3>{page_title_text}</h3>
            </body>
			<body style="font-size:20px;">
				<h3>{pre_hed}</h3>
				<p>{pre_text}</p>
				<img src={{bias_image}} style="max-width: 80%;">
			</body>
			<body style="font-size:20px;">
				<h3>{train_hed}</h3>
				<img src={{loss_image_loc}} class="center">
			</body>
			<body style="font-size:20px;">
				<h3>{bias_model_perf_hed}</h3>
				<p>{bias_model_perf_text}</p>
				{df.to_html(classes='mystyle')}
				{df1.to_html(classes='mystyle')}
			</body>
			<body style="font-size:20px;">
				<h3>{bias_model_perf_hed_peaks}</h3>
				<p>{bias_model_perf_text_peaks}</p>
				{pdf.to_html(classes='mystyle')}
				{pdf1.to_html(classes='mystyle')}
			</body>
			<body style="font-size:20px;">
				<h3>{tf_hed}</h3>
				<p>{tf_text_profile}</p>
			</body>
			<body>
				 {table_profile}
			</body>
			<body style="font-size:20px;">
				<p>{tf_text_counts}</p>
			</body>
			<body>
				 {table_counts}
			</body>
					
		</html>
		'''

	# 3. Write the html string as an HTML file
	#with open('html_report.html', 'w') as f:
	#	f.write(html.format(bias_image=bias_image_loc, loss_image_loc=loss_image_loc))
	with open(os.path.join(prefix,"evaluation/{}overall_report.html".format(fpx)), 'w') as f:
		f.write(html.format(bias_image=bias_image_loc,loss_image_loc=loss_image_loc))

	from weasyprint import HTML, CSS
	css = CSS(string='''
		@page {
                size: 450mm 700mm;
                mnargin: 0in 0in 0in 0in;
                }
        .center {
                 max-width:25%;
                 max-height:5%;
                 display: block;
                 margin-left: auto;
                 margin-right: auto;
                 }
        .cover {
    		 width: 100%;
   			 display: block;
			}
			
		table {
  			   font-size: 11pt;
 			   font-family: Arial;
 			   text-align: center;
 		       width: 100%;
 		       border-collapse: collapse;
 			   border: 1px solid silver;
			}
        ''')
	#HTML('html_report.html').write_pdf('html_report.pdf', stylesheets=[css])
	HTML(os.path.join(prefix,"evaluation/{}overall_report.html".format(fpx))).write_pdf(os.path.join(prefix,"evaluation/{}overall_report.pdf".format(fpx)), stylesheets=[css])
	
if __name__=="__main__":
	args=read_args()
	main(args)