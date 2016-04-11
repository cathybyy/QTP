using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Windows.Forms;
using System.IO;
using System.Threading;
using System.Text.RegularExpressions;

using BitTcl;

namespace QuickTestPlatform
{
    public partial class Main : Form
    {
        TestCase tcThroughput;
        TestCase tcPortManagement;
        TestCase tcStopQT;

        private string logFile = System.IO.Directory.GetCurrentDirectory() + "/log.txt";
        private string resPath = System.IO.Directory.GetCurrentDirectory() + "/respath.txt";


        /// <summary>
        /// 初始化tcl解释器进程
        /// </summary>
        /// <param name="script">脚本名</param>
        /// <returns></returns>
        private BitTcl.TestCase InitTclWroker(string script)
        {
            string scriptFile = System.IO.Directory.GetCurrentDirectory() + "/scripts/" + script;
            string content = "";
            if (System.IO.File.Exists(scriptFile))
            {
                System.IO.StreamReader sr = new System.IO.StreamReader(scriptFile);
                content = sr.ReadToEnd();
                sr.Close();
            }
            else
            {
                throw new Exception("Script not found");
            }
            BitTcl.TestCase tc = new BitTcl.TestCase(content);
            return tc;
        }

        /// <summary>
        /// 将参数设为默认
        /// </summary>
        private void SetDefault()
        {
            checkBoxRfc2544All.Checked = false;
            checkBoxRfc2889All.Checked = false;
            checkBoxSpeedAll.Checked = false;
            checkBoxFSAll.Checked = false;

            checkBoxThroughput.Checked = true;
            comboBoxLatencyAlg.SelectedIndex = 1;
            comboBoxGroup.SelectedIndex = 0;
            checkBox1G.Checked = true;
            comboBoxMedia.SelectedIndex = 0;
            comboBoxNego.SelectedIndex = 2;
            checkBoxFS512.Checked = true;
            radioButtonPortPair.Select();
            radioButtonMAC.Select();
            textBoxIpAddrStart.Text = "100.1.0.2";
            textBoxIpAddrStep.Text = "0.0.0.2";
            textBoxGwAddrStart.Text = "100.1.0.1";
            textBoxGwAddrStep.Text = "0.0.0.2";
            textBoxPrefixLen.Text = "24";
            textBoxPortStep.Text = "0.1.0.0";
            textBoxJumbo.Text = "9216";
            numericUpDownTestDuration.Value = 20;
            numericUpDownLnRate.Value = 100;
            numericUpDownFsPerAddr.Value = 10;
            checkBoxSendMACOnly.Checked = false;
        }

        /// <summary>
        /// 获取界面参数
        /// </summary>
        /// <param name="c">父控件</param>
        /// <param name="paramStr">初始参数字符串</param>
        /// <returns>参数字符串</returns>
        private string GetParam(Control c,string paramStr)
        {

            if (c.HasChildren)
            {
                if (c is NumericUpDown)
                {
                    if (c.Tag == null)
                    {
                        return "";
                    }
                    else
                    {
                        paramStr += " " + c.Tag.ToString() + " " + ((NumericUpDown)c).Value;
                    }
                }
                else
                {
                    foreach (Control child in c.Controls)
                    {
                        string tempStr = GetParam(child, paramStr);
                        if (tempStr.Length > 0)
                        {
                            paramStr = tempStr;
                        }
                    }
                }
            }
            else
            {
                if (c.Tag == null)
                {
                    return "";
                }
                if (c.Tag.ToString().Length > 0)
                {
                    if (c is CheckBox)
                    {
                        if (((CheckBox)c).Checked)
                        {
                            paramStr += " " + c.Tag.ToString() + " 1";
                        }
                        else
                        {
                            paramStr += " " + c.Tag.ToString() + " 0";
                        }
                    }
                    if (c is RadioButton)
                    {
                        if (((RadioButton)c).Checked)
                        {
                            paramStr += " " + c.Tag.ToString() + " 1";
                        }
                        else
                        {
                            paramStr += " " + c.Tag.ToString() + " 0";
                        }
                    }
                    if (c is TextBox)
                    {
                        paramStr += " " + c.Tag.ToString() + " " + ((TextBox)c).Text;
                    }
                    if (c is ComboBox)
                    {
                        paramStr += " " + c.Tag.ToString() + " " + ((ComboBox)c).Text;
                    }

                }
            }

            return paramStr;
        }

        private void GenerateError(string errStr)
        {
            try
            {
                richTextBoxLog.SelectionColor = Color.DarkRed;
                GenerateLog(errStr);
            }
            catch
            { }
        }
        private void GenerateWarning(string warnStr)
        {
            richTextBoxLog.SelectionColor = Color.Orange;
            GenerateLog(warnStr);
        }
        private void GenerateHighlight(string hlStr)
        {
            richTextBoxLog.SelectionColor = Color.DarkGreen;
            GenerateLog(hlStr);
        }
        private void GenerateLog(string logStr)
        {
            string info = DateTime.Now.ToLongDateString() + DateTime.Now.ToLongTimeString() + ":" + logStr + "\n";
            richTextBoxLog.AppendText(info);
            richTextBoxLog.Invalidate(true);

            StreamWriter sw;
            if (File.Exists(logFile))
            {
                sw = new StreamWriter(logFile, true, Encoding.UTF8);
            }
            else
            {
                sw = File.CreateText(logFile);
            }
            sw.WriteLine(info);
            sw.Close();

        }

        private void RefreshChassisInfo(string chasInfo)
        {
            string[] portInfo = chasInfo.Split(' ');
            List<string> portList = new List<string>();
            List<String> snList = new List<string>() { "XM2-P1022662" };
            string sn = portInfo[0];
            if (snList.IndexOf(sn) != -1)
            {
                for (int i = 1; i < portInfo.Length; i++)
                {
                    if (portInfo[i].Length > 0)
                        portList.Add(portInfo[i]);
                }

                foreach (string info in portList)
                {
                    string info_chas = "";
                    string info_card = "";
                    string info_port = "";
                    string[] info_list = info.Split(':');
                    if (info_list.Length > 2)
                    {
                        info_chas = info_list[0];
                        info_card = info_list[1];
                        info_port = info_list[2];
                    }

                    if (treeViewChassisTree.Nodes.ContainsKey(info_chas) == false)
                    {
                        TreeNode tn1 = treeViewChassisTree.Nodes.Add(info_chas, info_chas);
                        TreeNode tn2 = tn1.Nodes.Add(info_card, "Card" + info_card);
                        tn2.Tag = info_card;
                        TreeNode tn3 = tn2.Nodes.Add(info_port, "Port" + info_port);
                        tn3.Tag = info_port;
                    }
                    else
                    {
                        TreeNode tn1 = treeViewChassisTree.Nodes.Find(info_chas, false)[0];
                        if (tn1.Nodes.ContainsKey(info_card) == false)
                        {
                            TreeNode tn2 = tn1.Nodes.Add(info_card, "Card" + info_card);
                            tn2.Tag = info_card;
                            TreeNode tn3 = tn2.Nodes.Add(info_port, "Port" + info_port);
                            tn3.Tag = info_port;
                        }
                        else
                        {
                            TreeNode tn2 = tn1.Nodes.Find(info_card, false)[0];
                            if (tn2.Nodes.ContainsKey(info_port) == false)
                            {
                                TreeNode tn3 = tn2.Nodes.Add(info_port, "Port" + info_port);
                                tn3.Tag = info_port;
                            }
                        }
                    }
                }
            }
            else
            {
                GenerateError("The SN of the chassis if not avaliable!");
            }
        }
        private void RefreshSelectPort()
        {
            List<string> portList = new List<string>();
            if (treeViewChassisTree.Nodes.Count > 0)
            {
                foreach (TreeNode tn1 in treeViewChassisTree.Nodes)
                {
                    if (tn1.Nodes.Count > 0)
                    {
                        foreach (TreeNode tn2 in tn1.Nodes)
                        {
                            if (tn2.Nodes.Count > 0)
                            {
                                foreach (TreeNode tn3 in tn2.Nodes)
                                {
                                    if (tn3.Checked)
                                    {
                                        portList.Add(tn1.Text + ":" + tn2.Tag.ToString() + ":" + tn3.Tag.ToString());
                                    }
                                }
                            }
                        }
                    }
                }
            }

            listViewSelectedPorts.Items.Clear();
            foreach (string item in portList)
            {
                listViewSelectedPorts.Items.Add(item);
            }
        }
        private void LoadResult()
        {
            string resultFile = testResPathStr + "\\QTP.log";
            if (File.Exists(resultFile))
            {
                StreamReader sr = new StreamReader(resultFile);
                string result = sr.ReadToEnd();
                string[] resultLine = result.Split('\n');
                Regex rg = new Regex("Results");
                Regex rgHeader = new Regex("[a-zA-Z]+");
                List<string> resultList = new List<string>();
                resultList.AddRange(resultLine);
                //result list view
                GroupBox gb = new GroupBox();
                ListView lvResult = new ListView();
                flowLayoutPanelResultView.Controls.Clear();
                foreach (string rl in resultList)
                {
                    if (rg.IsMatch(rl))
                    {
                        GenerateResultHeader(rl);
                        GenerateHighlight(rl);

                        gb = new GroupBox();
                        gb.Text = rl;
                        lvResult = new ListView();
                        lvResult.View = View.Details;
                        gb.Width = 1000;
                        gb.Height = 100;
                        lvResult.GridLines = true;
                        lvResult.HeaderStyle = ColumnHeaderStyle.Nonclickable;
                        lvResult.Dock = DockStyle.Fill;
                        gb.Controls.Add(lvResult);
                    }
                    else
                    {
                        if (rgHeader.IsMatch(rl))
                        {
                            string[] headers = rl.Split(',');
                            for (int i = 0; i < headers.Length; i++)
                            {
                                if (headers[i].Trim().Length > 0)
                                {
                                    ColumnHeader ch = lvResult.Columns.Add(headers[i].Trim());
                                    ch.Width = 100;
                                }
                            }
                        }
                        else
                        {
                            ListViewItem item = new ListViewItem();
                            string[] bodies = rl.Split(',');
                            item.Text = bodies[0];
                            for (int i = 1; i < bodies.Length; i++)
                            {
                                if (bodies[i].Trim().Length > 0)
                                {
                                    item.SubItems.Add(bodies[i]);
                                }
                            }
                            lvResult.Items.Add(item);
                        }
                        GenerateResultBody(rl);
                        GenerateLog(rl);
                    }
                    flowLayoutPanelResultView.Controls.Add(gb);
                }
            }
        }
        private void GenerateResultHeader(string result)
        {
            richTextBoxResult.SelectionColor = Color.DarkGreen;
            richTextBoxResult.AppendText(result);
            richTextBoxResult.Invalidate(true);

        }
        private void GenerateResultBody(string result)
        {
            richTextBoxResult.AppendText(result);
            richTextBoxResult.Invalidate(true);

        }

        private string testPortStr = "";
        private string testParamStr = "";
        private string testResPathStr = "";

        public Main()
        {
            InitializeComponent();

            SetDefault();

            tcPortManagement = InitTclWroker("portmgr.tcl");
            tcThroughput = InitTclWroker("throughput.tcl");
            tcStopQT = InitTclWroker("stop.tcl");


            if (File.Exists(resPath))
            {
                StreamReader sr = new StreamReader(resPath);
                string repositoryResPath = sr.ReadToEnd();
                toolStripTextBoxResultPath.Text = repositoryResPath;
            }
            else
            {
                toolStripTextBoxResultPath.Text = System.IO.Directory.GetCurrentDirectory() + "\\Tcl\\Results";
            }
        }

        #region 读取机框端口
        private void backgroundWorkerPort_DoWork(object sender, DoWorkEventArgs e)
        {
            tcPortManagement.Run();
            tcPortManagement.WriteToTcl(toolStripTextBoxChasAddr.Text);
            while (tcPortManagement.ProcessStatus == BitTcl.TclWorker.Status.Running)
            {
                if (backgroundWorkerPort.CancellationPending)
                {
                    e.Cancel = true;
                    return;
                }
                backgroundWorkerPort.ReportProgress(tcPortManagement.Progress);
                System.Threading.Thread.Sleep(2000);

            }

        }

        private void backgroundWorkerPort_ProgressChanged(object sender, ProgressChangedEventArgs e)
        {

        }

        private void backgroundWorkerPort_RunWorkerCompleted(object sender, RunWorkerCompletedEventArgs e)
        {
            if (tcPortManagement.OUT.Length > 0)
            {
                GenerateLog("Add chassis " + toolStripTextBoxChasAddr.Text + " " + tcPortManagement.TclResult);
                GenerateLog("Chassis info " + tcPortManagement.OUT);
                RefreshChassisInfo(tcPortManagement.OUT);
            }
            else
            {
                GenerateError("Add chassis " + toolStripTextBoxChasAddr.Text + " " + tcPortManagement.TclResult);

            }
            toolStripButtonAddChas.Enabled = true;
            toolStripTextBoxChasAddr.ReadOnly = false;
        }

        #endregion

        #region 测试执行

        private void backgroundWorkerTest_DoWork(object sender, DoWorkEventArgs e)
        {


            tcThroughput.Run();
            tcThroughput.WriteToTcl(testPortStr);
            tcThroughput.WriteToTcl(testParamStr);
            tcThroughput.WriteToTcl(testResPathStr);

            while (tcThroughput.ProcessStatus == BitTcl.TclWorker.Status.Running)
            {
                if (backgroundWorkerTest.CancellationPending)
                {
                    e.Cancel = true;
                    tcThroughput.Stop();
                    return;
                }
                backgroundWorkerTest.ReportProgress(tcThroughput.Progress);
                System.Threading.Thread.Sleep(2000);

            }

        }

        private void backgroundWorkerTest_ProgressChanged(object sender, ProgressChangedEventArgs e)
        {
            progressBarTest.Value = e.ProgressPercentage;
        }

        private void backgroundWorkerTest_RunWorkerCompleted(object sender, RunWorkerCompletedEventArgs e)
        {
            buttonStart.Enabled = buttonSetDefault.Enabled = true;
            buttonStop.Enabled = false;
            this.Cursor = Cursors.Default;

            foreach (string log in tcThroughput.TclOutput)
            {
                GenerateLog(log);
            }
            progressBarTest.Value = 100;

            LoadResult();
        }


        #endregion

        private void checkBoxRfc2544All_CheckedChanged(object sender, EventArgs e)
        {
            checkBoxThroughput.Checked = checkBoxLatency.Checked
                = checkBoxFrameLoss.Checked = checkBoxBackToBack.Checked = checkBoxRfc2544All.Checked;
        }

        private void checkBoxRfc2889All_CheckedChanged(object sender, EventArgs e)
        {
            checkBoxFully.Checked = checkBoxHOL.Checked = checkBoxBackbone.Checked
                = checkBoxManyToOne.Checked = checkBoxOneToMany.Checked = checkBoxBroadcastRate.Checked
                = checkBoxRfc2889All.Checked;
        }

        private void checkBoxSpeedAll_CheckedChanged(object sender, EventArgs e)
        {
            checkBox10M.Checked = checkBox100M.Checked = checkBox1G.Checked
                = checkBox25G.Checked = checkBox40G.Checked = checkBox100G.Checked
                = checkBox10G.Checked = checkBoxSpeedAll.Checked;
        }

        private void checkBoxFSAll_CheckedChanged(object sender, EventArgs e)
        {
            checkBoxFS64.Checked = checkBoxFS128.Checked = checkBoxFS256.Checked
                = checkBoxFS512.Checked = checkBoxFS590.Checked = checkBoxFS1280.Checked
                = checkBoxFS1024.Checked = checkBoxJumbo.Checked = checkBoxFS1518.Checked = checkBoxFSAll.Checked;
        }

        private void buttonSetDefault_Click(object sender, EventArgs e)
        {
            SetDefault();
        }

        private void toolStripButtonAddChas_Click(object sender, EventArgs e)
        {
            if (toolStripTextBoxChasAddr.Text.Length > 0)
            {
                GenerateHighlight("ADD CHASSIS");
                this.TopMost = true;
                backgroundWorkerPort.RunWorkerAsync();
                toolStripButtonAddChas.Enabled = false;
                toolStripTextBoxChasAddr.ReadOnly = true;
                Thread.Sleep(500);
                this.TopMost = false;
            }
        }

        private void treeViewChassisTree_AfterCheck(object sender, TreeViewEventArgs e)
        {
            TreeNode tn = e.Node;
            if (tn.Nodes.Count > 0)
            {
                foreach (TreeNode node in tn.Nodes)
                {
                    node.Checked = tn.Checked;
                }
            }
            RefreshSelectPort();
        }

        private void treeViewTestSuit_AfterCheck(object sender, TreeViewEventArgs e)
        {
            TreeNode tn = e.Node;
            if (tn.Nodes.Count > 0)
            {
                foreach (TreeNode node in tn.Nodes)
                {
                    node.Checked = tn.Checked;
                }
            }
        }

        private void toolStripButtonUp_Click(object sender, EventArgs e)
        {
            if (listViewSelectedPorts.SelectedItems.Count > 0)
            {
                int index = listViewSelectedPorts.SelectedItems[0].Index;
                if (index > 0)
                {
                    ListViewItem item = listViewSelectedPorts.SelectedItems[0];
                    listViewSelectedPorts.Items.RemoveAt(index);
                    listViewSelectedPorts.Items.Insert(index - 1, item);
                }
            }
        }

        private void toolStripButtonDn_Click(object sender, EventArgs e)
        {
            if (listViewSelectedPorts.SelectedItems.Count > 0)
            {
                int index = listViewSelectedPorts.SelectedItems[0].Index;
                if (index < listViewSelectedPorts.Items.Count-1)
                {
                    ListViewItem item = listViewSelectedPorts.SelectedItems[0];
                    listViewSelectedPorts.Items.RemoveAt(index);
                    listViewSelectedPorts.Items.Insert(index+1, item);
                }
            }
        }

        private void toolStripButtonCollapse_Click(object sender, EventArgs e)
        {
            treeViewChassisTree.CollapseAll();
        }

        private void toolStripButtonExpend_Click(object sender, EventArgs e)
        {
            treeViewChassisTree.ExpandAll();
        }

        private void buttonStart_Click(object sender, EventArgs e)
        {
//check for test port
            if (listViewSelectedPorts.Items.Count == 0)
            {
                MessageBox.Show("No test ports selected.", "Start Abort", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }
            GenerateHighlight("START TEST");
//gray out start and set default button, enable stop button
            buttonStart.Enabled = buttonSetDefault.Enabled = false;
            buttonStop.Enabled = true;
//collect test port string for tcl
            string portStr = "{";
            foreach (ListViewItem item in listViewSelectedPorts.Items)
            {
                portStr += item.Text + " ";
            }
            portStr += "}";
            testPortStr = portStr;
//collect test param string for tcl
            string paramStr = GetParam(flowLayoutPanelThroughput, "");
            testParamStr = paramStr;
//collect result id string for tcl
            string resId = DateTime.Now.Ticks.ToString();
            testResPathStr =toolStripTextBoxResultPath.Text.Trim() + "\\" + resId;

            this.TopMost = true;
            backgroundWorkerTest.RunWorkerAsync();
            Thread.Sleep(1000);
            this.TopMost = false;

            progressBarTest.Value = 0;
        }

        private void buttonStop_Click(object sender, EventArgs e)
        {
            backgroundWorkerTest.CancelAsync();

            this.Cursor = Cursors.WaitCursor;
            this.TopMost = true;
            tcStopQT.Run();
            Thread.Sleep(2000);
            this.TopMost = false;
            tcStopQT.WaitEnd();
        }

        private void toolStripButtonResultPathBrowse_Click(object sender, EventArgs e)
        {
            DialogResult result = folderBrowserDialogResultPath.ShowDialog();
            if (result == System.Windows.Forms.DialogResult.OK)
            {
                toolStripTextBoxResultPath.Text = folderBrowserDialogResultPath.SelectedPath;
                StreamWriter sw;
                if (File.Exists(resPath))
                {
                    sw = new StreamWriter(resPath, false, Encoding.UTF8);
                }
                else
                {
                    sw = File.CreateText(resPath);
                }
                sw.WriteLine(toolStripTextBoxResultPath.Text.Trim());
                sw.Close();
            }
        }

        private void toolStripAddChassis_ItemClicked(object sender, ToolStripItemClickedEventArgs e)
        {

        }

        private void flowLayoutPanel10_Paint(object sender, PaintEventArgs e)
        {

        }

    }
}
