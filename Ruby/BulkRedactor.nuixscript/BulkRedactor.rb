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

dialog = TabbedCustomDialog.new("Bulk Redactor")
general_tab = dialog.addTab("general_tab","General Settings")

general_tab.appendHeader("#{$current_selected_items.size} items selected")

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

expressions_tab = dialog.addTab("expressions_tab","Regular Expressions")
expressions_tab.appendStringList("expressions")

phrases_tab = dialog.addTab("phrases_tab","Terms & Phrases")
phrases_tab.appendStringList("phrases")

named_entity_choices = $current_case.getAllEntityTypes.map{|name| Choice.new(name,name)}
named_entities_tab = dialog.addTab("named_entities_tab","Named Entities")
named_entities_tab.appendChoiceTable("named_entities","",named_entity_choices)

dialog.validateBeforeClosing do |values|
	# If settings state that user is creating a markup set, we need to make sure they
	# actually provided a usable markup set name
	if !values["use_existing_markup_set"] && (values["new_markup_set_name"].nil? || values["new_markup_set_name"].strip.empty?)
		CommonDialogs.showWarning("Please provide a markup set name")
		next false
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

		br.findAndRedact($current_case,settings,$current_selected_items)

		pd.setCompleted
	end
end