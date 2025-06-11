import pyodbc

from transplant_nlp import initialize_transplant_pipeline

####################################################
###             DB CONFIGURATION                 ###
####################################################

SERVER = 'your_server_here'
DATABASE = 'your_database_here'

# this string works for sql server with integrated security, please replace with another connection string as necessary
connectionString = f'DRIVER={{ODBC Driver 17 for SQL Server}};SERVER={SERVER};DATABASE={DATABASE};Trusted_Connection=yes'

####################################################
###             TABLE CONFIGURATION              ###
####################################################

dest_table = "your_destination_table"
overwrite_existing_table = True

####################################################
###             BATCHING CONFIGURATION           ###
####################################################
start = 0
end = 1000000
batch = 20000

# query that allows batching for a row number field using between
# will be used as query.format(start, start+batch) in processing loop
batched_note_selection_query = '''SELECT DocumentID, DocumentText
      FROM your_note_table
      WHERE rowno BETWEEN {} AND {} AND DocumentText IS NOT NULL'''

####################################################
###                RUNNING PIPELINE              ###
####################################################

conn = pyodbc.connect(connectionString)
cursor = conn.cursor()

create_query = f''''''
if overwrite_existing_table:
    create_query = f'''drop table if exists {dest_table};'''
create query += f'''create table {dest_table}
    (
    tiudocumentsid bigint,
    span varchar(max),
    label varchar(100),
    start_char int,
    end_char int,
    modifier varchar(max) null,
    modifier_label varchar(100) null,
    is_historical bit, 
    is_negated bit 
    )'''
input_query = f'''insert into {dest_table} (tiudocumentsid, span, label, start_char, end_char, modifier, modifier_label, is_historical, is_negated) values (?, ?, ?, ?, ?, ?, ?, ?, ?)'''

nlp = initialize_transplant_pipeline()

while start < end:
    result = cursor.execute(batched_note_selection_query.format(start, start+batch)).fetchall()
    print(f"Read batch {start} to {start+batch}, size {len(result)}")
    start += batch
    
    for res in result:
        # process text with NLP pipeline
        doc = nlp(res[1])
        start_set = set()
        # generate output using context graph first, gathering branches of the context tree that are not of type date event, historical, or negated
        for edge in doc._.context_graph.edges:
            span = edge[0]
            mod = edge[1]
            if mod.category != 'HISTORICAL' and mod.category != 'NEGATED_EXISTENCE' and mod.category != 'DATE_EVENT':
                # add the anchor term's start index to a set so we do not grab it again
                start_set.add(span.start_char)
                row = [res[0], span.text, span.label_, span.start_char, span.end_char, doc[mod._start:mod._end].text, mod.category, span._.is_historical, span._.is_negated]
                output.append(row)
        # then gather all entities that were not captured within the context graph
        for ent in doc.ents:
            if ent.label_ != 'DATE' and ent.label_ != 'RELATIVE_DATE' and ent.label_ != 'EXCLUDE':
                if ent.start_char not in start_set:
                    row = [res[0], ent.text, ent.label_, ent.start_char, ent.end_char, None, None, ent._.is_historical, ent._.is_negated]
                    start_set.add(ent.start_char)
                    output.append(row)
                    
        # write every 5000 rows to database to prevent progress loss
        if len(output) > 5000:
            cursor.executemany(input_query, output)
            conn.commit()
            output = []
            print(f"Writing batch to database")
cursor.executemany(input_query, output)
conn.commit()

conn.close()
print("Finished processing transplant notes")