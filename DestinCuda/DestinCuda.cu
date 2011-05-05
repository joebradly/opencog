#include "AdviceData.h"
#include "DestinData.h"
#include "DestinLayer.h"

#include <iostream>
#include <stdio.h>
#include <vector>
#include <fstream>
#include <ctime>
#include <sstream>
#include <sys/stat.h>
#include <math.h>

#ifdef _WIN32
#include <direct.h>
#include <string>
#else
// Linux only requirements...
#include <errno.h>
#include <unistd.h>
#include <string.h>
#include <stdlib.h>
#endif

using namespace std;

void PrintHelp()
{
    // ***************************
    // Print out how to use DeSTIN
    // ***************************

    cout << "Usage: DestinCuda CodeWord MAXCNT LayerToShow ParamsFile TrainingDataFile DestinOutputFile TargetDirectory [OutputDistillationLevel]" << endl;
    cout << "Where:" << endl;
    cout << "    CodeWord must have 11 digits RRRRXXYYYYY" << endl;
    cout << "        RRRR  = 0000 to 9999 where 0000 is real random time." << endl;
    cout << "        XX    = 01 to 99 number of classes will not be higher then training file." << endl;
    cout << "        YYYYY = 00000 to 99999 number of examples of each class." << endl;
    cout << "                00000 means RANDOMLY PICK EXAMPLES until we finish clustering, period, up to max iterations." << endl;
    cout << "    MAXCNT is the number of digits we show it to train the unsupervised DeSTIN architecture" << endl;
    cout << "    LayerToShow = layer written to output file; it is given as S:E:O:P:T where " << endl;
    cout << "        S = first layer to write" << endl;
    cout << "        E = last layer to write" << endl;
    cout << "        O = offset for movements to write" << endl;
    cout << "        P = period of movements to write" << endl;
    cout << "        T = type.  Nothing (and no !) is beliefs.  Type can be: " << endl;
    cout << "            A is belief in advice states computed by tabular method." << endl;
    cout << "            N is belief in advice states computed by neural network function approximator." << endl;
    cout << "            L is belief in advice states computed by linear function approximator." << endl;
    cout << "    ParamsFile is a file that has the run parameters" << endl;
    cout << "    TrainingDataFile is the binary data file for training.  A testing file with the SAME NAME and appended with _TESTING is assumed" << endl;
    cout << "    DestinOutputFile is the name of the DeSTIN network output file for saving." << endl;
    cout << "         Use -D as default, which is the experiment number with a .dat at the end, in the TargetDirectory directory" << endl;
    cout << "    TargetDirectory is where we want to put the MAIN OUTPUT DATA FILES.  We ALWAYS write an experiment marker to the " << endl;
    cout << "        ../DiagnosticData area.  But if you are writing out a lot of data you can specify another directory." << endl;
    cout << "        Put D for default which is the ../DiagnosticData area." << endl;
    cout << "    [OutputDistillationLevel] is optional.  If this exists it must be a number and currently its got to be 0.  "<<endl;
    cout << "        0 = regular outputs with a lot of details about movements and processing: this is our input to SampleAndStack"<<endl;
    cout << "        1 = outputs compatible with the regular distilled output of SampleAndStack. If you use this you can skip SampleAndStack.exe" << endl;
    cout << endl;
    cout << "-OR-" << endl;
    cout << endl;
    cout << "Usage: DestinCuda -F InputNetworkFile LayerToShow ParamsFile TrainingDataFile DestinOutputFile TargetDirectory [OutputDistillationLevel]" << endl;
    cout << "Where:" << endl;
    cout << "    -F signifies use a saved DeSTIN network file " << endl;
    cout << "    InputNetworkFile is the NAME of the saved DeSTIN network file" << endl;
    cout << "    All others are as in first usage type" << endl;
    cout << endl;
}

bool FileExists(string strFilename)
{
    // **************************
    // Does the given file exists
    // **************************
    // For detailed information look the return values of stat

    struct stat stFileInfo;
    bool blnReturn;
    int intStat;

    // Attempt to get the file attributes
    intStat = stat(strFilename.c_str(),&stFileInfo);
    if(intStat == 0) {
        // File exists
        blnReturn = true;
    }
    else
    {
        // File not exists or no permission
        blnReturn = false;
    }

    return(blnReturn);
}

string GetNextFileForDiagnostic()
{
    // *************************************
    // Find next available experimental file
    // *************************************
    // Check if there is a previous experiment inside ../DiagnosticData

    string strFileName;
    int iExperimentNumber=-1;
    bool bFileFound = true;
    while ( bFileFound )
    {
        iExperimentNumber++;
        stringstream buffer;
        buffer << "../DiagnosticData/DestinDiagnostics" << iExperimentNumber << ".csv";
        strFileName =  buffer.str();

        bFileFound = FileExists(strFileName);
    }
    strFileName = strFileName.substr(18);

    return strFileName;
}

void GetParameters(const char* cFilename, int& NumberOfLayers, double*& dcMu, double*& dcSigma, double*& dcRho,
                   int*& NumberOfStates,
            bool& bAveraging,bool& bFFT,bool& bBinaryPOS,int* DistanceMeasureArray,
            bool& bUseStarvationTrace,int& PSSAUpdateDelay,bool& bIgnoreAdvice,
            int**& SEQ, int& SEQ_LENGTH, string& sFileContents, int& iBlocksToProcess,
            bool& bBasicOnlineClustering,
            bool& bClanDestin, bool& bInitialLayerIsTransformOnly,bool& bUseGoodPOSMethod )
{
    // **************************************
    // Read the config file (parameters file)
    // **************************************
    ifstream stmInput;
    stmInput.open(cFilename);
    vector<string> vFileContents;
    string sNextLine;
    char cBuffer[1024];

    // Put the config file into a vector and as one big string back to sFileCOntents
    sFileContents = "~PARAMETERSFILE:";
    sFileContents += cFilename + ":";
    while ( stmInput.eof() == false )
    {
        stmInput.getline(cBuffer,1024);
        if ( stmInput.eof() == false )
        {
            sFileContents += "~" + cBuffer + "\n";
            sNextLine = cBuffer;
            vFileContents.push_back(sNextLine);
        }
    }
    stmInput.close();
    sFileContents += "~";


}

bool CreateDestinOnTheFly(string ParametersFileName, string& sNetworkFile, int& NumberOfLayers, DestinLayer*& DLayers,
                          int iTestSequence, int FirstLayerToShowHECK, int LastLayerToShow, int MAX_CNT, string& sCommandLineData,
                          DestinData& DataSourceForTraining, string& sDiagnosticFileName, string& sDestinTrainingFileName,
                          vector< pair<int,int> >& vIndicesAndGTLabelToUse,
                          map<int,int>& LabelsUsedToCreateNetwork, map<int,int>& IndicesUsedToCreateNetwork, float* BufferForLogs,
                          int iLayerOfInputToShow, int iRowOfInputToShow, int iColOfInputToShow, int NumberOfMovementsToWrite)

{
    // *********************
    // Create DeSTIN network
    // *********************

    double* dcMu;
    double* dcSigma;
    double* dcRho;
    int* NumberOfCentroids;
    bool bAveraging;
    bool bFFT;
    bool bBinaryPOS;
    int DistanceMeasureArray[128];
    bool bUseStarvationTrace;
    int PSSAUpdateDelay;
    bool bIgnoreAdvice;
    int** SEQ;
    int SEQ_LENGTH;
    string sParametersFileContents;
    int iBlocksToProcess;
    bool bBasicOnlineClustering;
    bool bClanDestin;
    bool bInitialLayerIsTransformOnly;
    bool bDoGoodPOS = false;

    GetParameters(ParametersFileName.c_str(),NumberOfLayers,dcMu,dcSigma,dcRho,NumberOfCentroids,
        bAveraging,bFFT,bBinaryPOS,DistanceMeasureArray,
        bUseStarvationTrace,PSSAUpdateDelay,bIgnoreAdvice,SEQ,SEQ_LENGTH,
        sParametersFileContents,iBlocksToProcess,
        bBasicOnlineClustering, bClanDestin, bInitialLayerIsTransformOnly,bDoGoodPOS);

    return 0;
}

int MainDestinExperiments(int argc, char* argv[])
{
    // ********************************************
    // Main experiment of DeSTIN (Also called main)
    // ********************************************

    // File for diagnostic
    string strDiagnosticFileName;
    strDiagnosticFileName = GetNextFileForDiagnostic();

    // arguments processing

    // For debug information we output the command line to our Diagnostic file.
    string strCommandLineData = "";
    for( int i=0; i<argc; i++ )
    {
        strCommandLineData += argv[i];
        strCommandLineData += " ";
    }

    // Argument: TargetDirectory
    // A given location instead or default
    string strDiagnosticDirectoryForData;
    string strArg7 = argv[7];
    if ( strArg7 == "D" )
    {
        strDiagnosticDirectoryForData = "../DiagnosticData/";
    }
    else
    {
        // Buffer with path + filename where to put diagnostic data
        stringstream buffer;
        buffer << strArg7.c_str() << "/";
        strDiagnosticDirectoryForData = buffer.str();
    }

    // Argument: DestinOutputFile or InputNetworkFile
    bool bCreateFromFile;
    string strDestinNetworkFileToRead;
    string strDestinNetworkFileToWrite;
    string FirstArg = argv[1];
    if ( FirstArg=="-F" )
    {
        // Argument: InputNetworkFile
        bCreateFromFile = true;
        strDestinNetworkFileToRead = argv[2];  // we read from this file...

        if ( !FileExists( strDestinNetworkFileToRead ) )
        {
            cout << "designated input network file named " << strDestinNetworkFileToRead.c_str() << " does not exist" << endl;
            return 0;
        }
        cout << "Writing destin file to: " << strDestinNetworkFileToWrite << endl;
    }
    else
    {
        // Argument: DestinOutputFile
        bCreateFromFile = false;
        strDestinNetworkFileToWrite = argv[6]; // we write to this file, and then we read from it too!!
        if ( strDestinNetworkFileToWrite == "-D" )
        {
            // If given -D
            strDestinNetworkFileToWrite= strDiagnosticDirectoryForData + strDiagnosticFileName + ".dat";
            cout << "Writing default destin file to: " << strDestinNetworkFileToWrite << endl;
        }
        strDestinNetworkFileToRead = strDestinNetworkFileToWrite;
    }
    // Create the old variable sDiagnosticFileNameForMarking
    // it have the location based on TargetDirectory + FileName
    string sDiagnosticFileNameForMarking;
    sDiagnosticFileNameForMarking = strDiagnosticDirectoryForData + strDiagnosticFileName;

    // Argument: LayerToShow
    // Structure of processing S:E:O:P:T
    // List of default values
    int FirstLayerToShowHECK = 3;
    int LastLayerToShow = FirstLayerToShowHECK;
    int iMovementOutputOffset = 0;
    int iMovementOutputPeriod = 1;
    OutputTypes eTypeOfOutput = eBeliefs;

    string sLayerSpecs = argv[3];
    int iColon = sLayerSpecs.find(":");
    if ( iColon == -1 || sLayerSpecs.substr(iColon).empty() )  //first layer = last layer, and no sampling specified.
    {
        // S
        FirstLayerToShowHECK=atoi(sLayerSpecs.c_str());
        LastLayerToShow=FirstLayerToShowHECK;
    }
    else
    {
        // S:E
        FirstLayerToShowHECK=atoi(sLayerSpecs.substr(0,1).c_str());
        LastLayerToShow=atoi(sLayerSpecs.substr(iColon+1,1).c_str());
        sLayerSpecs = sLayerSpecs.substr(iColon+1);
        iColon = sLayerSpecs.find(":");
        if ( iColon!=-1 && !( sLayerSpecs.substr(iColon).empty() ) )
        {
            //S:E:O
            sLayerSpecs = sLayerSpecs.substr(iColon+1);
            iMovementOutputOffset = atoi(sLayerSpecs.substr(0,1).c_str());
            iColon = sLayerSpecs.find(":");
            if ( iColon!=-1 && !( sLayerSpecs.substr(iColon).empty() ) )
            {
                //S:E:O:P
                sLayerSpecs = sLayerSpecs.substr(iColon+1);
                iMovementOutputPeriod = atoi(sLayerSpecs.substr(0,1).c_str());
                iColon = sLayerSpecs.find(":");
                if ( iColon!=-1 && !( sLayerSpecs.substr(iColon).empty() ) )
                {
                    //S:E:O:P:T
                    sLayerSpecs = sLayerSpecs.substr(iColon+1);
                    if ( sLayerSpecs.substr(0,1)=="A" )
                    {
                        eTypeOfOutput = eBeliefInAdviceTabular;
                    }
                    else if ( sLayerSpecs.substr(0,1)=="B" )
                    {
                        eTypeOfOutput = eBeliefs;
                    }
                    else if ( sLayerSpecs.substr(0,1)=="N" )
                    {
                        eTypeOfOutput = eBeliefInAdviceNNFA;
                    }
                    else if ( sLayerSpecs.substr(0,1)=="L" )
                    {
                        eTypeOfOutput = eBeliefInAdviceLinearFA;
                    }
                    else
                    {
                        cout << "Do not understand the output type " << sLayerSpecs.c_str() << endl;
                        return 0;
                    }
                }
            }
        }
    }

    // Optional argument: OutputDistillationLevel
    // This will write out a distilled movement log file this movement log matches that what SampleAndStack would produce.
    int OutputDistillationLevel = 0; //default level
    if ( argc == 9 )
    {
        OutputDistillationLevel = atoi(argv[8]);
    }

    // **********************
    // Loading data source(s)
    // **********************
    // Arguments: TrainingDataFile
    // Load the training file for DeSTIN
    string strDestinTrainingFileName = argv[5];

    // Data object containing source training
    DestinData DataSourceForTraining;

    int NumberOfUniqueLabels;
    DataSourceForTraining.LoadFile(strDestinTrainingFileName.c_str());
    NumberOfUniqueLabels = DataSourceForTraining.GetNumberOfUniqueLabels();
    if ( NumberOfUniqueLabels==0 )
    {
        cout << "There seems to be something off with data source " << strDestinTrainingFileName.c_str() << endl;
        return 0;
    }

    // A vector with all the labels of the data source
    vector<int> vLabelList;
    DataSourceForTraining.GetUniqueLabels(vLabelList);

    // Load the test file for DeSTIN
    string strTesting = strDestinTrainingFileName;
    strTesting = strTesting + "_TESTING";
    // Data object of test source
    DestinData DataSourceForTesting;

    DataSourceForTesting.LoadFile((char*)(strTesting.c_str()));
    if ( DataSourceForTesting.GetNumberOfUniqueLabels()!=NumberOfUniqueLabels )
    {
        cout << "Test set does not have the same number of labels as train set " << endl;
        return 0;
    }

    // **************************
    // Preparing working data set
    // **************************
    // now get the data set creation parameters
    int NumberOfUniqueLabelsToUse;
    int MAX_CNT = 1000;
    int iTestSequence = 0;
    string ParametersFileName;
    vector< pair<int,int> > vIndicesAndGTLabelToUse;

    if ( bCreateFromFile==false )
    {
        // Argument: MAXCNT
        MAX_CNT=atoi(argv[2]);
        // Argument: CodeWord
        iTestSequence=atoi(argv[1]);
        string sCodeWord=argv[1];
        if (sCodeWord.length() != 11 )
        {
            PrintHelp();
            return 0;
        }
        // First part of code word RRRR = for time seeding
        string sNumInp;
        sNumInp= sCodeWord.substr(0,4);

        // if the first 4 digits are 0000 make a TRUE random, otherwise use the complete number.
        int iReserve = atoi( sNumInp.c_str() );
        if ( iReserve == 0 )
        {
            srand( time(NULL) );
        }
        else
        {
            int iRandSeed = iTestSequence;
            srand( (unsigned int)iRandSeed );
        }

        // Second part of code word XX = number of inputs
        sNumInp = sCodeWord.substr(4,2);
        NumberOfUniqueLabelsToUse = atoi( sNumInp.c_str() );

        // Last part of code word YYYYY
        int iNumberOfExamplesFromEachLabel;
        sNumInp = sCodeWord.substr(6,5);
        iNumberOfExamplesFromEachLabel=atoi( sNumInp.c_str() );

        // if iNumberOfExamplesFromEachLabel is 0 we randomly pick examples from the available
        // classes and only show them ONE TIME
        // Generate the examples from the dictates given here.
        vector< pair<int,int> > LabelsAndIndicesForUse;
        cout << "------------------" << endl;
        int DestinTrainSampleStep = 1;
        if(iNumberOfExamplesFromEachLabel == 0)
        {
            DestinTrainSampleStep = 25;
        }
        for(int iLabel=0;iLabel<NumberOfUniqueLabelsToUse;iLabel++)
        {
            int cnt = 0;
            vector<int> IndicesForThisLabel;
            DataSourceForTraining.GetIndicesForThisLabel(iLabel,IndicesForThisLabel);
            if ( IndicesForThisLabel.size() > iNumberOfExamplesFromEachLabel && iNumberOfExamplesFromEachLabel != 0)
            {
                for(int jj=0;jj<iNumberOfExamplesFromEachLabel;jj++)
                {
                    cnt++;
                    pair<int,int> P;
                    P.first = IndicesForThisLabel[jj];
                    P.second = iLabel;
                    LabelsAndIndicesForUse.push_back(P);
                }
            }
            else
            {
                for(int jj=0;jj<IndicesForThisLabel.size();jj=jj+DestinTrainSampleStep)
                {
                    cnt++;
                    pair<int,int> P;
                    P.first = IndicesForThisLabel[jj];
                    P.second = iLabel;
                    LabelsAndIndicesForUse.push_back(P);
                }

            }
            cout << "Label: " << iLabel << " got " << cnt << " unique sample(s)." << endl;
        }
        iNumberOfExamplesFromEachLabel = LabelsAndIndicesForUse.size()/NumberOfUniqueLabelsToUse;

        // Now generate MAX_CNT+1000 random numbers from 0 to LabelsAndIndicesForUse-1
        // and use these to populate vIndicesAndGTLabelToUse

        // Debug list of labels to be used
        int Picked[NumberOfUniqueLabels];
        for(int jj=0;jj<NumberOfUniqueLabels;jj++)
        {
            Picked[jj]=0;
        }

        int Digit;
        int iChoice;
        for(int jj=0;jj<MAX_CNT;jj++)
        {
            //pick the digit first...
            Digit = rand() % NumberOfUniqueLabelsToUse;
            iChoice = Digit * iNumberOfExamplesFromEachLabel;
            iChoice = iChoice+rand() % iNumberOfExamplesFromEachLabel;

            pair<int,int> P;
            P = LabelsAndIndicesForUse[iChoice];

            vIndicesAndGTLabelToUse.push_back( P );
            // Debug counter of labels used by label
            Picked[P.second] += 1;
        }

        // Debug information on amount of examples we use each label
        cout << "------------------" << endl;
        for(int jj=0;jj<NumberOfUniqueLabels;jj++)
        {
            cout << "Label: " << jj << " will show " << Picked[jj] << " sample(s)." << endl;
        }
        cout << "------------------" << endl;
    }  //check on bCreateFromFile==false
    else
    {
        // TODO: We want to create the network from an INPUT FILE!
        cout << "We want to create the network from an INPUT FILE!" << endl;
    }

    // Argument: ParamsFile
    // A configuration file for DeSTIN
    ParametersFileName=argv[4];
    if ( !FileExists(ParametersFileName) )
    {
        // According to the help the ParamsFile is always used? Maybe some vital information on how to load data?
        // Or some testing to see how the network reacts when expanding or shrinking the network.
        cout << "Parameters file name does not exist" << endl;
        return 0;
    }

    // ***********************
    // Creating DeSTIN network
    // ***********************
    // Yes its going to happen we going to create the network where we are waiting for.
    // The movement log records are unacceptably slow. Don't know why but it seems to be related to allocation & deallocating memory
    // so instead make a single big old pool here so each one that needs a bunch of memory won't really have to realloc & dealloc it each time.
    // TODO: See if this can be done different.
    float* BufferForMovementLogRecords;
    BufferForMovementLogRecords = new float[1024*4*64*128];  //this should be enough for all movements and all layers / nodes

    DestinLayer* DLayer;
    map<int,int> LabelsUsedToCreateNetwork;
    map<int,int> IndicesUsedToCreateNetwork;
    int NumberOfLayers=4;
    if ( !bCreateFromFile )
    {
        int LayerToShow=-1;   //normally this should be -1 for regular operation.  For debugging, set it to 0 to look at the particular input for layer 0
        int RowToShowInputs=3;
        int ColToShowInputs=3;

        CreateDestinOnTheFly(ParametersFileName, strDestinNetworkFileToWrite, NumberOfLayers, DLayer, iTestSequence, FirstLayerToShowHECK,
            LastLayerToShow, MAX_CNT, strCommandLineData, DataSourceForTraining, sDiagnosticFileNameForMarking, strDestinTrainingFileName,
            vIndicesAndGTLabelToUse, LabelsUsedToCreateNetwork, IndicesUsedToCreateNetwork, BufferForMovementLogRecords,
            LayerToShow, RowToShowInputs, ColToShowInputs, 0);  // no movements to write, as we don't write DeSTIN responses out in this case
    }
    else
    {
        // even if you don't create the file here, we want to mark the experiment number so make a dummy file...
        ofstream stmDummy;
        stmDummy.open(strDiagnosticFileName.c_str(),ios::out);
        stmDummy << strCommandLineData.c_str() << endl;
        stmDummy << "DummyHeader" << endl;
        stmDummy.close();
    }

    if ( !FileExists(strDestinNetworkFileToRead) )
    {
        cout << "Destin network file " << strDestinNetworkFileToRead.c_str() << " not found!" << endl;
        return 0;
    }

    return 0;
}

int main(int argc, char* argv[])
{
    // ********************
    // Startup check DeSTIN
    // ********************
    // There should be 8 or 9 arguments at this time if not show how to use DeSTIN
    if ( argc==8 || argc==9 )
    {
        return MainDestinExperiments(argc,argv);
    }
    else
    {
        PrintHelp();
        return 0;
    }
}
