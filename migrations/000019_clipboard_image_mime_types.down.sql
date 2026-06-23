ALTER TABLE clipboard_entries
    DROP CONSTRAINT IF EXISTS clipboard_content_type_check;

ALTER TABLE clipboard_entries
    ADD CONSTRAINT clipboard_content_type_check
        CHECK (content_type IN (
            'text/plain', 'text/uri-list', 'text/html', 'text/rtf',
            'text', 'image', 'url', 'file_ref', 'html', 'rtf'
        ));
