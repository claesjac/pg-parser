#include <postgres.h>
#include <miscadmin.h>
#include <utils/memutils.h>
#include <utils/timestamp.h>

static void dummy_cleanup(int code, Datum args) {
    
}

static void myexit(void) {
    fprintf(stderr, "In my exit");
}

void InitEmbeddedPostgres(void) {
    MyProcPid = getpid();
	MyStartTime = time(NULL);

	MemoryContextInit();

    return;
    
	InitializeGUCOptions();
	    
	if (!SelectConfigFiles("postgres-db", "postgres")) {
		proc_exit(1);
	}
	
	Assert(DataDir);
	ValidatePgVersion(DataDir);
	ChangeToDataDir();
	CreateDataDirLockFile(false);
	BaseInit();
	InitProcess();
	
	InitPostgres("postgres", InvalidOid, "postgres", NULL);
	
	SetProcessingMode(NormalProcessing);
	BeginReportingGUCOptions();
											   
	PgStartTime = GetCurrentTimestamp();
	
    on_proc_exit(dummy_cleanup, 0);
}

void CloseEmbeddedPostgres(void) {
    proc_exit_prepare(0);
}