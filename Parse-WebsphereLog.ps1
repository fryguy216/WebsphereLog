# Load necessary .NET assemblies for the GUI
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Global variable to hold all parsed log entries for quick filtering ---
$allLogEntries = [System.Collections.ArrayList]::new()

# --- Define the Regular Expression ---
$logRegex = '(?m)^\[(?<timestamp>\d{1,2}\/\d{1,2}\/\d{2}\s\d{1,2}:\d{2}:\d{2}:\d{3}\s[A-Z]{3})\]\s+(?<thread>[0-9a-fA-F]+)\s+(?<logger>\S+)\s+(?<level>[A-Z])\s+(?<message>[\s\S]+?)(?=\n^\[\d{1,2}\/\d{1,2}\/\d{2}|\Z)'

# --- Build the Main Form (Window) ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "PowerShell WebSphere Log Parser"
$form.Size = New-Object System.Drawing.Size(1200, 700)
$form.StartPosition = 'CenterScreen'

# --- Create Controls ---

# Button to load a new file
$loadButton = New-Object System.Windows.Forms.Button
$loadButton.Text = "Load Log File..."
$loadButton.Location = New-Object System.Drawing.Point(10, 12)
$loadButton.AutoSize = $true

# GroupBox to contain the filter controls
$filterBox = New-Object System.Windows.Forms.GroupBox
$filterBox.Text = "Filters"
$filterBox.Location = New-Object System.Drawing.Point(10, 45)
$filterBox.Size = New-Object System.Drawing.Size(1160, 60)
$filterBox.Anchor = 'Top, Left, Right'

# Thread ID filter controls
$threadLabel = New-Object System.Windows.Forms.Label
$threadLabel.Text = "Thread ID:"
$threadLabel.Location = New-Object System.Drawing.Point(15, 25)
$threadLabel.AutoSize = $true
$threadTextBox = New-Object System.Windows.Forms.TextBox
$threadTextBox.Location = New-Object System.Drawing.Point(85, 22)
$threadTextBox.Size = New-Object System.Drawing.Size(120, 20)

# Level filter controls
$levelLabel = New-Object System.Windows.Forms.Label
$levelLabel.Text = "Level:"
$levelLabel.Location = New-Object System.Drawing.Point(225, 25)
$levelLabel.AutoSize = $true
$levelComboBox = New-Object System.Windows.Forms.ComboBox
$levelComboBox.Location = New-Object System.Drawing.Point(270, 22)
$levelComboBox.Items.AddRange(@("All", "I", "W", "E", "F", "O", "S"))
$levelComboBox.SelectedIndex = 0 # Default to "All"
$levelComboBox.DropDownStyle = 'DropDownList' # Prevent user from typing custom text

# Filter and Clear buttons
$filterButton = New-Object System.Windows.Forms.Button
$filterButton.Text = "Apply Filter"
$filterButton.Location = New-Object System.Drawing.Point(390, 20)
$filterButton.Size = New-Object System.Drawing.Size(100, 25)

$clearButton = New-Object System.Windows.Forms.Button
$clearButton.Text = "Clear"
$clearButton.Location = New-Object System.Drawing.Point(500, 20)
$clearButton.Size = New-Object System.Drawing.Size(80, 25)

# Add controls to the GroupBox
$filterBox.Controls.AddRange(@($threadLabel, $threadTextBox, $levelLabel, $levelComboBox, $filterButton, $clearButton))

# ListView (Grid View) to display results
$listView = New-Object System.Windows.Forms.ListView
$listView.View = 'Details'
$listView.GridLines = $true
$listView.FullRowSelect = $true
$listView.Location = New-Object System.Drawing.Point(10, 115)
$listView.Size = New-Object System.Drawing.Size(($form.ClientSize.Width - 20), ($form.ClientSize.Height - 125))
$listView.Anchor = 'Top, Bottom, Left, Right'

# Define ListView Columns
$listView.Columns.Add("Timestamp", 150) | Out-Null
$listView.Columns.Add("Thread ID", 100) | Out-Null
$listView.Columns.Add("Logger", 150) | Out-Null
$listView.Columns.Add("Level", 50, 'Center') | Out-Null
$listView.Columns.Add("Message", 700) | Out-Null


# --- Core Functions ---

# Function to update the ListView based on current data and filters
function Update-ListView {
    $listView.Items.Clear()
    
    # Get filter values
    $threadFilter = $threadTextBox.Text
    $levelFilter = $levelComboBox.SelectedItem
    
    $filteredEntries = $allLogEntries
    
    # Apply filters if specified
    if (-not [string]::IsNullOrEmpty($threadFilter)) {
        $filteredEntries = $filteredEntries | Where-Object { $_.Thread -like "*$threadFilter*" }
    }
    if ($levelFilter -ne "All") {
        $filteredEntries = $filteredEntries | Where-Object { $_.Level -eq $levelFilter }
    }
    
    # Use BeginUpdate/EndUpdate to speed up the process
    $listView.BeginUpdate()
    foreach ($entry in $filteredEntries) {
        $item = New-Object System.Windows.Forms.ListViewItem($entry.Timestamp)
        $item.SubItems.Add($entry.Thread) | Out-Null
        $item.SubItems.Add($entry.Logger) | Out-Null
        $item.SubItems.Add($entry.Level) | Out-Null
        $item.SubItems.Add($entry.Message) | Out-Null
        $listView.Items.Add($item) | Out-Null
    }
    $listView.EndUpdate()

    # Auto-size columns to fit content and header
    foreach ($column in $listView.Columns) {
        $column.Width = -2 
    }
    
    $form.Text = "PowerShell WebSphere Log Parser - $($listView.Items.Count) records displayed"
}


# --- Button Click Events ---

$loadButton.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title = "Select a WebSphere Log File"
    $openFileDialog.Filter = "Log Files (*.log)|*.log|Output Files (*.out)|*.out|All files (*.*)|*.*"

    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $filePath = $openFileDialog.FileName
        $form.Text = "Parsing: $filePath"
        $allLogEntries.Clear() # Clear previous file's data
        $listView.Items.Clear()
        [System.Windows.Forms.Application]::DoEvents() # Force UI update
        
        try {
            $content = Get-Content -Path $filePath -Raw
            $matches = [regex]::Matches($content, $logRegex)
            
            # Parse all matches into the global ArrayList
            foreach ($match in $matches) {
                $logObject = [PSCustomObject]@{
                    Timestamp = $match.Groups['timestamp'].Value
                    Thread    = $match.Groups['thread'].Value
                    Logger    = $match.Groups['logger'].Value
                    Level     = $match.Groups['level'].Value
                    Message   = $match.Groups['message'].Value.Trim()
                }
                $allLogEntries.Add($logObject) | Out-Null
            }
        }
        catch {
            [System.Windows.Forms.MessageBox]::Show("An error occurred while reading or parsing the file: `n$($_.Exception.Message)", "Error", "OK", "Error")
        }
        
        # Call the update function to populate the view for the first time
        Update-ListView
    }
})

$filterButton.Add_Click({
    Update-ListView
})

$clearButton.Add_Click({
    $threadTextBox.Text = ""
    $levelComboBox.SelectedIndex = 0
    Update-ListView
})


# --- Add all controls to the Form and Show It ---
$form.Controls.AddRange(@($loadButton, $filterBox, $listView))
[void]$form.ShowDialog()
