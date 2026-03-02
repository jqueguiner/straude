
-- Allow authenticated users to insert notifications where they are the actor.
-- This lets the follow/kudos/comment routes write notifications for other users
-- while preventing impersonation (actor_id must match the caller).
CREATE POLICY "Authenticated users can insert notifications as actor"
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (actor_id = auth.uid());
;
