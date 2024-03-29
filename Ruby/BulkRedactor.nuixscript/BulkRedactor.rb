script_directory = File.dirname(__FILE__)
require File.join(script_directory,"Nx.jar")
java_import "com.nuix.nx.NuixConnection"
java_import "com.nuix.nx.LookAndFeelHelper"
java_import "com.nuix.nx.dialogs.ChoiceDialog"
java_import "com.nuix.nx.dialogs.TabbedCustomDialog"
java_import "com.nuix.nx.dialogs.CommonDialogs"
java_import "com.nuix.nx.dialogs.ProgressDialog"
java_import "com.nuix.nx.dialogs.ProcessingStatusDialog"
java_import "com.nuix.nx.digest.DigestHelper"
java_import "com.nuix.nx.controls.models.Choice"

LookAndFeelHelper.setWindowsIfMetal
NuixConnection.setUtilities($utilities)
NuixConnection.setCurrentNuixVersion(NUIX_VERSION)

require File.join(script_directory,"SuperUtilities.jar")
java_import com.nuix.superutilities.annotations.BulkRedactor
java_import com.nuix.superutilities.annotations.BulkRedactorSettings
java_import com.nuix.superutilities.SuperUtilities

# Initialize super utilities
$su = SuperUtilities.init($utilities,NUIX_VERSION)

java_import java.util.regex.Pattern

items_without_text = $current_case.searchUnsorted("has-text:0")
selected_items_without_text = $utilities.getItemUtility.intersection($current_selected_items,items_without_text)
if selected_items_without_text.size > 0
	if selected_items_without_text.size == $current_selected_items.size
		message = "All #{selected_items_without_text.size} selected items do not have text and therefore cannot be bulk redacted.\n"+
			"Consider performing OCR on these items before running this script.  Items without text can be located with the query:\n"+
			"has-text:0\n\nThe script will now exit..."
		CommonDialogs.showError(message)
		exit 1
	else
		message = "#{selected_items_without_text.size} of the #{$current_selected_items.size} selected items do not have text and therefore cannot be bulk redacted.\n"+
			"Consider performing OCR on these items before running this script.  Items without text can be located with the query:\n"+
			"has-text:0"
		CommonDialogs.showWarning(message)
	end
end

dialog = TabbedCustomDialog.new("Bulk Redactor")
dialog.setHelpUrl("https://github.com/Nuix/Bulk-Redactor")

general_tab = dialog.addTab("general_tab","General Settings")
general_tab.appendHeader("#{$current_selected_items.size} items selected, #{selected_items_without_text.size} do not have text")

existing_markup_set_names = $current_case.getMarkupSets.map{|ms| ms.getName}
if existing_markup_set_names.size > 0
	general_tab.appendRadioButton("use_existing_markup_set","Use Existing Markup Set","markup_set_group",true)
	general_tab.appendComboBox("existing_markup_set_name","Existing Markup Set",existing_markup_set_names)
	general_tab.enabledOnlyWhenChecked("existing_markup_set_name","use_existing_markup_set")
	general_tab.appendRadioButton("create_new_markup_set","Create New Markup Set","markup_set_group",false)
	general_tab.appendTextField("new_markup_set_name","New Markup Set Name","")
	general_tab.enabledOnlyWhenChecked("new_markup_set_name","create_new_markup_set")
else
	general_tab.appendTextField("new_markup_set_name","New Markup Set Name","")
end

general_tab.appendHeader(" ")
general_tab.appendDirectoryChooser("temp_directory","Temp Directory")
default_temp_directory = File.join($current_case.getLocation.getAbsolutePath,"TemporaryPDFs")
default_temp_directory = default_temp_directory.gsub("/","\\")
general_tab.setText("temp_directory",default_temp_directory)
general_tab.appendRadioButton("apply_redactions","Apply Redactions","markup_operation_group",true)
general_tab.appendRadioButton("apply_highlights","Apply Higlights","markup_operation_group",false)
general_tab.appendRadioButton("apply_nothing","Don't Apply Markups (still reports)","markup_operation_group",false)
general_tab.appendCheckableTextField("generate_report",false,"report_file","","Save Report CSV to")
general_tab.appendSpinner("concurrency","Concurrency",1,1,128)

expressions_tab = dialog.addTab("expressions_tab","Regular Expressions")
expressions_tab.appendHeader("Note: Provided regular expressions are matched in a case sensitive manner!")
expressions_tab.appendStringList("expressions",true)

dialog.addMenu("Expressions","Generate expression from Phrase/Term...") do
	phrase = CommonDialogs.getInput("Phrase or term to convert to a regular expression:","")
	if phrase.nil? == false
		dialog.setSelectedTabIndex(1)
		expression = BulkRedactorSettings.phraseToExpression(phrase)
		expression = "\\b#{expression}\\b"
		expressions_tab.getControl("expressions").addValue(expression)
	end
end

dialog.addMenu("Expressions","Import Phrase/Term list as expressions...") do
	list_file = CommonDialogs.openFileDialog("C:\\","Text File (*.txt)","txt","Import Phrase/Term List as Expressions")
	if !list_file.nil? && list_file.exists
		dialog.setSelectedTabIndex(1)
		expressions_control = expressions_tab.getControl("expressions")
		File.open(list_file.getAbsolutePath).each do |line|
			if line.nil? == false
				expression = BulkRedactorSettings.phraseToExpression(line)
				expression = "\\b#{expression}\\b"
				expressions_control.addValue(expression)
			end
		end
	end
end

phrases_tab = dialog.addTab("phrases_tab","Terms & Phrases")
phrases_tab.appendHeader("Note: Provided phrases/terms are matched in a case insensitive manner!")
phrases_tab.appendStringList("phrases",true)

named_entity_choices = $current_case.getAllEntityTypes.map{|name| Choice.new(name,name)}
named_entities_tab = dialog.addTab("named_entities_tab","Named Entities")
if named_entity_choices.size < 1
	named_entities_tab.appendHeader("Current case has no named entities.")
end
named_entities_tab.appendChoiceTable("named_entities","",named_entity_choices)

dialog.validateBeforeClosing do |values|
	if !values["apply_nothing"]
		# If settings state that user is creating a markup set, we need to make sure they
		# actually provided a usable markup set name
		if !values["use_existing_markup_set"] && (values["new_markup_set_name"].nil? || values["new_markup_set_name"].strip.empty?)
			CommonDialogs.showWarning("Please provide a markup set name")
			next false
		end
	end

	# Make sure at least 1 regex or phrase/term was provided
	if values["expressions"].size < 1 && values["phrases"].size < 1 && values["named_entities"].size < 1
		CommonDialogs.showWarning("Please provide at least 1 expression, phrase or named entity type.")
		next false
	end

	# Check regular expressions validity
	if values["expressions"].size > 0
		values["expressions"].each do |expression|
			begin
			rescue Exception => exc
			end
		end
	end

	# Make sure user specified a temp directory
	if values["temp_directory"].nil? || values["temp_directory"].strip.empty?
		CommonDialogs.showWarning("Please specify a temp directory")
		next false
	end

	if values["generate_report"] && values["report_file"].strip.empty?
		CommonDialogs.showWarning("Please supply a report CSV file path.")
		next false
	end

	if !values["generate_report"] && values["apply_nothing"]
		CommonDialogs.showWarning("Please select a markup type or enable report generation.")
		next false
	end

	next true
end

dialog.display
if dialog.getDialogResult == true
	values = dialog.toMap

	markup_set_name = nil
	if !values["use_existing_markup_set"]
		markup_set_name = values["new_markup_set_name"]
	else
		markup_set_name = values["existing_markup_set_name"]
	end

	expressions = values["expressions"]
	phrases = values["phrases"]
	named_entities = values["named_entities"]
	temp_directory = values["temp_directory"]

	apply_redactions = values["apply_redactions"]
	apply_highlights = values["apply_highlights"]
	apply_nothing = values["apply_nothing"]

	generate_report = values["generate_report"]
	report_file = values["report_file"]

	concurrency = values["concurrency"]

	ProgressDialog.forBlock do |pd|
		pd.setTitle("Bulk Redactor")
		pd.setAbortButtonVisible(false)

		br = BulkRedactor.new
		settings = BulkRedactorSettings.new
		settings.setMarkupSetName(markup_set_name)
		settings.setTempDirectory(temp_directory)
		settings.setExpressions(expressions)
		settings.addPhrases(phrases)
		settings.setNamedEntityTypes(named_entities)

		if apply_redactions
			settings.setApplyRedactions(true)
			settings.setApplyHighLights(false)
		elsif apply_highlights
			settings.setApplyRedactions(false)
			settings.setApplyHighLights(true)
		elsif apply_nothing
			settings.setApplyRedactions(false)
			settings.setApplyHighLights(false)
		end

		br.whenMessageLogged do |message|
			pd.logMessage(message)
			puts message
		end

		br.whenProgressUpdated do |info|
			pd.setMainProgress(info.getCurrent,info.getTotal)
			pd.setMainStatus("(#{info.getCurrent}/#{info.getTotal}) Matches: #{info.getMatches}")
			if info.getCurrent == info.getTotal
				pd.logMessage("(#{info.getCurrent}/#{info.getTotal}) Matches: #{info.getMatches}")
			end
		end

		regions = br.findAndMarkup($current_case,settings,$current_selected_items,concurrency)

		if generate_report
			pd.setMainStatusAndLogIt("Generating report CSV...")
			require 'csv'
			java.io.File.new(report_file).getParentFile.mkdirs
			CSV.open(report_file,"w:utf-8") do |csv|
				headers = [
					"GUID",
					"Name",
					"Page",
					"Matched Text",
					"X",
					"Y",
					"WIDTH",
					"HEIGHT",
				]
				csv << headers
				regions.each_with_index do |region,region_index|
					pd.setMainProgress(region_index+1,regions.size)
					pd.setSubStatus("#{region_index+1}/#{regions.size}")
					item = region.getItem
					row_values = [
						item.getGuid,
						item.getLocalisedName,
						region.getPageNumber,
						region.getText,
						region.getX,
						region.getY,
						region.getWidth,
						region.getHeight,
					]
					csv << row_values
				end
			end
		end

		pd.setCompleted
	end
end